-- HuellaViva UAN · Migración 2: RLS, funciones seguras, auditoría y vistas agregadas

-- ===== Funciones de rol (leen user_roles, que el usuario no puede editar) =====
create or replace function public.tiene_rol(r rol_app)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles where user_id = auth.uid() and rol = r);
$$;

create or replace function public.es_admin_ambiental()
returns boolean language sql stable security definer set search_path = public as $$
  select public.tiene_rol('admin_ambiental');
$$;

-- ===== Habilitar RLS en TODAS las tablas =====
alter table public.profiles            enable row level security;
alter table public.user_roles          enable row level security;
alter table public.consent_versions    enable row level security;
alter table public.consents            enable row level security;
alter table public.survey_periods      enable row level security;
alter table public.surveys             enable row level security;
alter table public.activity_answers    enable row level security;
alter table public.emission_factors    enable row level security;
alter table public.tariffs             enable row level security;
alter table public.calculations        enable row level security;
alter table public.calculation_details enable row level security;
alter table public.data_requests       enable row level security;
alter table public.admin_audit_log     enable row level security;

-- ===== Participante: solo lo suyo =====
create policy perfil_propio_sel on public.profiles for select using (id = auth.uid());
create policy perfil_propio_ins on public.profiles for insert with check (id = auth.uid());
create policy perfil_propio_upd on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

create policy roles_propios_sel on public.user_roles for select using (user_id = auth.uid());
-- Sin políticas de insert/update/delete: solo el administrador técnico desde el panel de Supabase (service_role, nunca en el navegador).

create policy consent_vers_lectura on public.consent_versions for select to authenticated using (true);

create policy consents_propios_sel on public.consents for select using (profile_id = auth.uid());
create policy consents_propios_ins on public.consents for insert with check (profile_id = auth.uid());
create policy consents_propios_upd on public.consents for update using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy periodos_lectura on public.survey_periods for select to authenticated using (true);
create policy periodos_admin on public.survey_periods for all using (public.es_admin_ambiental()) with check (public.es_admin_ambiental());

-- Encuesta: requiere consentimiento vigente y periodo abierto (RF-01, RF-03)
create policy encuestas_propias_sel on public.surveys for select using (profile_id = auth.uid());
create policy encuestas_propias_ins on public.surveys for insert with check (
  profile_id = auth.uid()
  and exists (select 1 from public.consents c
              where c.id = consent_id and c.profile_id = auth.uid() and c.revoked_at is null)
  and exists (select 1 from public.survey_periods p where p.id = period_id and p.status = 'abierto')
);
create policy encuestas_propias_upd on public.surveys for update using (
  profile_id = auth.uid()
  and exists (select 1 from public.survey_periods p where p.id = period_id and p.status = 'abierto')
) with check (profile_id = auth.uid());

create policy respuestas_propias on public.activity_answers for all
  using (exists (select 1 from public.surveys s where s.id = survey_id and s.profile_id = auth.uid()))
  with check (exists (select 1 from public.surveys s where s.id = survey_id and s.profile_id = auth.uid()
                      and s.status <> 'retirada'));

create policy factores_lectura on public.emission_factors for select to authenticated using (true);
create policy factores_admin_ins on public.emission_factors for insert with check (public.es_admin_ambiental());
create policy factores_admin_upd on public.emission_factors for update using (public.es_admin_ambiental());

create policy tarifas_lectura on public.tariffs for select to authenticated using (true);
create policy tarifas_admin on public.tariffs for all using (public.es_admin_ambiental()) with check (public.es_admin_ambiental());

create policy calc_propios on public.calculations for select
  using (exists (select 1 from public.surveys s where s.id = survey_id and s.profile_id = auth.uid()));
create policy calc_det_propios on public.calculation_details for select
  using (exists (select 1 from public.calculations c join public.surveys s on s.id = c.survey_id
                 where c.id = calculation_id and s.profile_id = auth.uid()));
-- Los cálculos solo se escriben con la función calcular_encuesta (security definer).

create policy solicitudes_propias_sel on public.data_requests for select using (profile_id = auth.uid());
create policy solicitudes_propias_ins on public.data_requests for insert with check (profile_id = auth.uid());

create policy auditoria_admin_sel on public.admin_audit_log for select using (public.es_admin_ambiental());

-- ===== Factores: nunca sobrescribir el valor de un factor (RF-07) =====
create or replace function public.proteger_factor()
returns trigger language plpgsql as $$
begin
  if new.factor_value <> old.factor_value or new.unit_activity <> old.unit_activity
     or new.code <> old.code or new.version <> old.version then
    raise exception 'No se modifica un factor existente: cree una nueva versión';
  end if;
  return new;
end $$;
create trigger trg_proteger_factor before update on public.emission_factors
  for each row execute function public.proteger_factor();

create or replace function public.auditar_factor()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.admin_audit_log(actor_id, action, entity, entity_id, before_json, after_json)
  values (auth.uid(), tg_op, 'emission_factors', new.id,
          case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new));
  return new;
end $$;
create trigger trg_auditar_factor after insert or update on public.emission_factors
  for each row execute function public.auditar_factor();

-- ===== Cálculo reproducible (RF-04) =====
-- Busca el factor vigente al cierre del periodo para cada respuesta y guarda el detalle.
create or replace function public.calcular_encuesta(p_survey uuid)
returns numeric language plpgsql security definer set search_path = public as $$
declare
  v_survey surveys%rowtype; v_period survey_periods%rowtype;
  v_calc uuid; v_total numeric := 0; v_personas int;
  r record; v_factor emission_factors%rowtype; v_act numeric; v_conv numeric;
begin
  select * into v_survey from surveys where id = p_survey;
  if v_survey.profile_id <> auth.uid() then raise exception 'Sin permiso'; end if;
  select * into v_period from survey_periods where id = v_survey.period_id;
  v_personas := coalesce(v_survey.personas_hogar, 1);

  -- CR-01: si no hay kWh (E01) pero sí valor de factura (E02), estimar kWh = valor / tarifa del estrato
  -- (E02.text_value guarda el estrato 1-6; vacío = tarifa plena CU + COT)
  if not exists (select 1 from activity_answers where survey_id = p_survey and question_code = 'E01')
     and exists (select 1 from activity_answers where survey_id = p_survey and question_code = 'E02') then
    insert into activity_answers(survey_id, category, question_code, numeric_value, unit, is_estimated)
    select p_survey, 'electricidad', 'E01',
           round(a.numeric_value / t.cop_kwh, 1), 'kWh', true
      from activity_answers a
      join tariffs t on t.period_id = v_survey.period_id
                    and t.estrato is not distinct from nullif(a.text_value, '')::smallint  -- estrato opcional
     where a.survey_id = p_survey and a.question_code = 'E02'
     order by t.operador
     limit 1;
  end if;

  insert into calculations(survey_id, methodology_version, total_kgco2e)
  values (p_survey, v_period.methodology_version, 0) returning id into v_calc;

  for r in select * from activity_answers where survey_id = p_survey and numeric_value is not null loop
    v_factor := null;
    -- Mapeo pregunta -> actividad del factor
    select * into v_factor from emission_factors f
     where f.activity = case
             when r.question_code = 'E01' then 'electricidad_sin'
             when r.question_code = 'G02' then 'gas_natural'
             when r.question_code = 'G03' then 'glp'
             when r.question_code = 'T03' then (select text_value from activity_answers a
                                                where a.survey_id = p_survey and a.question_code = 'T02' and a.tramo = r.tramo)
             when r.question_code = 'V01' then 'vuelo_nacional'
             when r.question_code = 'V02' then (select 'vuelo_' || text_value from activity_answers a
                                                where a.survey_id = p_survey and a.question_code = 'V03')
           end
       and f.status in ('aprobado','provisional')
       and f.valid_from <= v_period.end_date
       and (f.valid_to is null or f.valid_to >= v_period.end_date)
     order by f.version desc limit 1;
    continue when v_factor.id is null;

    v_act := r.numeric_value;
    v_conv := case
      when r.question_code in ('E01','G02') then v_act / v_personas                       -- kWh o m3 por persona
      when r.question_code = 'G03' then v_act * coalesce((select numeric_value from activity_answers a
                where a.survey_id = p_survey and a.question_code = 'G04'), 40) * 0.45359237 / v_personas  -- kg GLP
      when r.question_code = 'T03' then v_act * coalesce((select numeric_value from activity_answers a
                where a.survey_id = p_survey and a.question_code = 'T01'), 0)
                / case when v_factor.activity in ('carro_gasolina') then
                       greatest(coalesce((select numeric_value from activity_answers a
                         where a.survey_id = p_survey and a.question_code = 'T04'), 1), 1) else 1 end   -- km
      when r.question_code = 'V01' then v_act * 700                                        -- km supuestos
      when r.question_code = 'V02' then v_act * case when v_factor.activity = 'vuelo_largo' then 8500 else 2000 end
    end;

    insert into calculation_details(calculation_id, answer_id, factor_id, category, activity_value, converted_value, emissions_kgco2e)
    values (v_calc, r.id, v_factor.id, r.category, v_act, v_conv, v_conv * v_factor.factor_value);
    v_total := v_total + v_conv * v_factor.factor_value;
  end loop;

  update calculations set total_kgco2e = round(v_total, 2) where id = v_calc;
  return round(v_total, 2);
end $$;

-- ===== Dashboard agregado (RF-06, RF-08, RF-10): solo grupos con >= 10 respuestas =====
create or replace function public.dashboard_agregado(p_period uuid default null)
returns table (periodo text, tipo_usuario tipo_usuario, campus text, categoria categoria,
               n_participantes bigint, promedio_kg numeric, mediana_kg numeric)
language sql stable security definer set search_path = public as $$
  with ultimo as (
    select distinct on (c.survey_id) c.* from calculations c order by c.survey_id, c.calculated_at desc
  ), base as (
    select sp.name periodo, pr.tipo_usuario, coalesce(pr.campus,'Sin dato') campus,
           d.category, s.id survey_id, sum(d.emissions_kgco2e) kg
    from ultimo u
    join surveys s on s.id = u.survey_id and s.status = 'enviada'
    join survey_periods sp on sp.id = s.period_id
    join profiles pr on pr.id = s.profile_id
    join calculation_details d on d.calculation_id = u.id
    where p_period is null or s.period_id = p_period
    group by 1,2,3,4,5
  )
  select periodo, tipo_usuario, campus, category, count(*) n,
         round(avg(kg),1), round((percentile_cont(0.5) within group (order by kg))::numeric,1)
  from base
  where public.es_admin_ambiental()
  group by 1,2,3,4
  having count(*) >= 10;            -- regla de diseño: ocultar grupos pequeños
$$;
revoke all on function public.dashboard_agregado(uuid) from anon;
