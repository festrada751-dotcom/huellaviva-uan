-- HuellaViva UAN · Migración 4 (CR-04): encuesta sin recibos
-- Parámetros de estimación con fuente (electrodomésticos y cocina) y nuevo cálculo.
-- Reemplaza la estimación por valor de factura (CR-01). La tabla tariffs se conserva como histórico.

create table if not exists public.parametros_estimacion (
  codigo        text primary key,              -- AP_NEVERA, CO_DESAYUNO...
  grupo         text not null check (grupo in ('electrodomestico','cocina','conversion','movilidad','vuelo')),
  nombre        text not null,
  valor         numeric not null check (valor >= 0),
  unidad        text not null,                 -- Wh por hora de uso, L/persona/día, km...
  modo          text check (modo in ('dia','semana','fijo')),  -- cómo se pregunta el uso
  fuente        text not null,
  fuente_url    text not null,
  anio          int  not null,
  supuesto      text
);
alter table public.parametros_estimacion enable row level security;
create policy parametros_lectura on public.parametros_estimacion for select to authenticated using (true);
create policy parametros_admin on public.parametros_estimacion for all using (public.es_admin_ambiental()) with check (public.es_admin_ambiental());
grant select on public.parametros_estimacion to authenticated;
grant insert, update on public.parametros_estimacion to authenticated;

insert into public.parametros_estimacion (codigo, grupo, nombre, valor, unidad, modo, fuente, fuente_url, anio, supuesto) values
-- Electrodomésticos: consumo en una hora de uso (Wh), ENRE Argentina (tabla oficial de consumo básico)
('AP_NEVERA','electrodomestico','Nevera',90,'Wh por hora','fijo','ENRE – Consumo básico de electrodomésticos (heladera con freezer)','https://www.argentina.gob.ar/enre/uso-eficiente-y-seguro/consumo-basico-electrodomesticos',2026,'Encendida 24 h al día'),
('AP_AIRE','electrodomestico','Aire acondicionado',1013,'Wh por hora','dia','ENRE – Aire acondicionado 2200 frigorías (≈ 9.000 BTU)','https://www.argentina.gob.ar/enre/uso-eficiente-y-seguro/consumo-basico-electrodomesticos',2026,'Equipo convencional, no inverter'),
('AP_VENTILADOR','electrodomestico','Ventilador',90,'Wh por hora','dia','ENRE – Ventilador de pie','https://www.argentina.gob.ar/enre/uso-eficiente-y-seguro/consumo-basico-electrodomesticos',2026,null),
('AP_TV','electrodomestico','Televisor',90,'Wh por hora','dia','ENRE – Televisor LED 32" a 50"','https://www.argentina.gob.ar/enre/uso-eficiente-y-seguro/consumo-basico-electrodomesticos',2026,null),
('AP_PORTATIL','electrodomestico','Computador portátil',22,'Wh por hora','dia','ENRE – Notebook','https://www.argentina.gob.ar/enre/uso-eficiente-y-seguro/consumo-basico-electrodomesticos',2026,null),
('AP_PC','electrodomestico','Computador de escritorio',200,'Wh por hora','dia','ENRE – Computadora (CPU)','https://www.argentina.gob.ar/enre/uso-eficiente-y-seguro/consumo-basico-electrodomesticos',2026,null),
('AP_BOMBILLOS','electrodomestico','Bombillos LED',45,'Wh por hora','dia','ENRE – Lámpara LED 9 W','https://www.argentina.gob.ar/enre/uso-eficiente-y-seguro/consumo-basico-electrodomesticos',2026,'5 bombillos de 9 W encendidos a la vez'),
('AP_MICROONDAS','electrodomestico','Microondas',640,'Wh por hora','dia','ENRE – Microondas','https://www.argentina.gob.ar/enre/uso-eficiente-y-seguro/consumo-basico-electrodomesticos',2026,null),
('AP_LAVADORA','electrodomestico','Lavadora',175,'Wh por hora','semana','ENRE – Lavarropas automático 5 kg (agua fría)','https://www.argentina.gob.ar/enre/uso-eficiente-y-seguro/consumo-basico-electrodomesticos',2026,null),
('AP_PLANCHA','electrodomestico','Plancha',750,'Wh por hora','semana','ENRE – Plancha','https://www.argentina.gob.ar/enre/uso-eficiente-y-seguro/consumo-basico-electrodomesticos',2026,null),
('AP_HORNO','electrodomestico','Horno eléctrico',750,'Wh por hora','semana','ENRE – Horno eléctrico 25-30 L','https://www.argentina.gob.ar/enre/uso-eficiente-y-seguro/consumo-basico-electrodomesticos',2026,null),
('AP_SECADOR','electrodomestico','Secador de pelo',2000,'Wh por hora','semana','ENRE – Secador de cabello','https://www.argentina.gob.ar/enre/uso-eficiente-y-seguro/consumo-basico-electrodomesticos',2026,null),
-- Cocina: gas natural por persona y comida, Barranquilla (punto medio del rango), UPME 2006
('CO_DESAYUNO','cocina','Desayuno',25,'L de gas natural por persona al día',null,'UPME – Consumo final de energía (UN 2006), Tabla 1-10, Barranquilla','https://docs.upme.gov.co/DemandayEficiencia/Doc_Hemeroteca/Consumo_Final_Energia_UN_2006.pdf',2006,'Punto medio de 20–30 L'),
('CO_ALMUERZO','cocina','Almuerzo',60,'L de gas natural por persona al día',null,'UPME – Consumo final de energía (UN 2006), Tabla 1-10, Barranquilla','https://docs.upme.gov.co/DemandayEficiencia/Doc_Hemeroteca/Consumo_Final_Energia_UN_2006.pdf',2006,'Punto medio de 50–70 L'),
('CO_CENA','cocina','Cena',20,'L de gas natural por persona al día',null,'UPME – Consumo final de energía (UN 2006), Tabla 1-10, Barranquilla','https://docs.upme.gov.co/DemandayEficiencia/Doc_Hemeroteca/Consumo_Final_Energia_UN_2006.pdf',2006,'Punto medio de 10–30 L'),
-- Conversiones por equivalencia energética (poderes caloríficos FECOC)
('CV_GN_A_GLP','conversion','m³ de gas natural → kg de GLP',0.7375,'kg GLP por m³ de gas natural',null,'FECOC – PCI gas natural Guajira 33,4943 MJ/m³ ÷ LHV GLP Cartagena 45,4134 MJ/kg','https://app.upme.gov.co/Calculadora_Emisiones1/new/calculadora.html',2026,'Misma eficiencia de estufa'),
('CV_GN_A_KWH','conversion','m³ de gas natural → kWh eléctricos',9.304,'kWh por m³ de gas natural',null,'FECOC – PCI gas natural Guajira 33,4943 MJ/m³ ÷ 3,6 MJ/kWh','https://app.upme.gov.co/Calculadora_Emisiones1/new/calculadora.html',2026,'Misma eficiencia de estufa'),
('CV_SEMANAS_MES','conversion','Semanas por mes',4.345,'semanas',null,'52,14 semanas ÷ 12 meses','https://ghgprotocol.org/corporate-standard',2026,null),
('CV_DIAS_MES','conversion','Días por mes',30.4,'días',null,'365 días ÷ 12 meses','https://ghgprotocol.org/corporate-standard',2026,null),
-- Vuelos: distancia supuesta por vuelo
('VU_NACIONAL','vuelo','Vuelo dentro de Colombia',700,'km por vuelo',null,'Supuesto: Santa Marta–Bogotá ≈ 720 km','https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2026',2026,null),
('VU_CORTO','vuelo','Vuelo internacional cercano',2000,'km por vuelo',null,'Supuesto: Caribe, Centroamérica, sur de EE. UU.','https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2026',2026,null),
('VU_LARGO','vuelo','Vuelo internacional lejano',8500,'km por vuelo',null,'Supuesto: Europa, Asia, sur de Suramérica','https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2026',2026,null)
on conflict (codigo) do nothing;

-- Factor vigente de una actividad en una fecha (última versión aprobada o provisional)
create or replace function public.factor_vigente(p_activity text, p_fecha date)
returns public.emission_factors language sql stable security definer set search_path = public as $$
  select * from emission_factors
   where activity = p_activity and status in ('aprobado','provisional')
     and valid_from <= p_fecha and (valid_to is null or valid_to >= p_fecha)
   order by version desc limit 1;
$$;
revoke execute on function public.factor_vigente(text, date) from public, anon;

-- ===== Nuevo cálculo (método HV-2.0) =====
-- Códigos de respuesta:
--  E00 recibo de luz ('si'/'no') · E01 kWh del recibo · AP_* horas de uso (por día o por semana según el parámetro)
--  C01 con qué cocinan ('gas_natural','glp','electrica','lena','ninguno') · C02 m³ del recibo de gas (opcional)
--  CO_DESAYUNO / CO_ALMUERZO / CO_CENA = 1 si esa comida se cocina en casa
--  T01 medio principal · T02 km de ida (punto medio del rango) · T03 días por semana · T04 personas en el carro
--  VU_NACIONAL / VU_CORTO / VU_LARGO número de vuelos
create or replace function public.calcular_encuesta(p_survey uuid)
returns numeric language plpgsql security definer set search_path = public as $$
declare
  v_s surveys%rowtype; v_p survey_periods%rowtype; v_calc uuid; v_total numeric := 0;
  v_pers numeric; v_dias numeric; v_sem numeric;
  r record; f emission_factors%rowtype; v_conv numeric; v_m3 numeric; v_comb text; v_medio text;
begin
  select * into v_s from surveys where id = p_survey;
  if v_s.profile_id is distinct from auth.uid() then raise exception 'Sin permiso'; end if;
  select * into v_p from survey_periods where id = v_s.period_id;
  v_pers := greatest(coalesce(v_s.personas_hogar, 1), 1);
  select valor into v_dias from parametros_estimacion where codigo = 'CV_DIAS_MES';
  select valor into v_sem  from parametros_estimacion where codigo = 'CV_SEMANAS_MES';

  insert into calculations(survey_id, methodology_version, total_kgco2e)
  values (p_survey, 'HV-2.0', 0) returning id into v_calc;

  -- 1. Electricidad
  f := factor_vigente('electricidad_sin', v_p.end_date);
  if exists (select 1 from activity_answers where survey_id = p_survey and question_code = 'E01' and numeric_value is not null) then
    for r in select * from activity_answers where survey_id = p_survey and question_code = 'E01' loop
      v_conv := r.numeric_value / v_pers;
      insert into calculation_details (calculation_id, answer_id, factor_id, category, activity_value, converted_value, emissions_kgco2e) values (v_calc, r.id, f.id, 'electricidad', r.numeric_value, v_conv, v_conv * f.factor_value);
      v_total := v_total + v_conv * f.factor_value;
    end loop;
  else
    for r in select a.*, pe.valor, pe.modo from activity_answers a join parametros_estimacion pe on pe.codigo = a.question_code
              where a.survey_id = p_survey and pe.grupo = 'electrodomestico' and a.numeric_value is not null loop
      v_conv := r.valor / 1000.0 * case r.modo when 'fijo' then 24 * v_dias
                                               when 'semana' then r.numeric_value * v_sem
                                               else r.numeric_value * v_dias end / v_pers;   -- kWh por persona
      update activity_answers set is_estimated = true where id = r.id;
      insert into calculation_details (calculation_id, answer_id, factor_id, category, activity_value, converted_value, emissions_kgco2e) values (v_calc, r.id, f.id, 'electricidad', r.numeric_value, v_conv, v_conv * f.factor_value);
      v_total := v_total + v_conv * f.factor_value;
    end loop;
  end if;

  -- 2. Cocina
  select text_value into v_comb from activity_answers where survey_id = p_survey and question_code = 'C01';
  if v_comb in ('gas_natural','glp','electrica') then
    select a.numeric_value into v_m3 from activity_answers a where survey_id = p_survey and question_code = 'C02';
    if v_comb = 'gas_natural' and v_m3 is not null then
      v_m3 := v_m3 / v_pers;                                          -- recibo real
    else
      select coalesce(sum(pe.valor), 0) * v_dias / 1000.0 into v_m3   -- comidas × L/persona/día
        from activity_answers a join parametros_estimacion pe on pe.codigo = a.question_code
       where a.survey_id = p_survey and pe.grupo = 'cocina' and a.numeric_value = 1;
      update activity_answers set is_estimated = true where survey_id = p_survey and question_code = 'C01';
    end if;
    if v_m3 > 0 then
      if v_comb = 'gas_natural' then
        f := factor_vigente('gas_natural', v_p.end_date); v_conv := v_m3;
      elsif v_comb = 'glp' then
        f := factor_vigente('glp', v_p.end_date);
        v_conv := v_m3 * (select valor from parametros_estimacion where codigo = 'CV_GN_A_GLP');
      else
        f := factor_vigente('electricidad_sin', v_p.end_date);
        v_conv := v_m3 * (select valor from parametros_estimacion where codigo = 'CV_GN_A_KWH');
      end if;
      if f.id is not null then
        insert into calculation_details (calculation_id, answer_id, factor_id, category, activity_value, converted_value, emissions_kgco2e)
        select v_calc, a.id, f.id, 'gas', v_m3, v_conv, v_conv * f.factor_value
          from activity_answers a where a.survey_id = p_survey and a.question_code = 'C01';
        v_total := v_total + v_conv * f.factor_value;
      end if;
    end if;
  end if;

  -- 3. Movilidad
  select text_value into v_medio from activity_answers where survey_id = p_survey and question_code = 'T01';
  f := factor_vigente(v_medio, v_p.end_date);
  if f.id is not null then
    select a.* into r from activity_answers a where survey_id = p_survey and question_code = 'T02';
    v_conv := coalesce(r.numeric_value, 0) * 2
            * coalesce((select numeric_value from activity_answers where survey_id = p_survey and question_code = 'T03'), 0)
            * v_sem
            / case when v_medio = 'carro_gasolina'
                   then greatest(coalesce((select numeric_value from activity_answers where survey_id = p_survey and question_code = 'T04'), 1), 1)
                   else 1 end;
    if v_conv > 0 then
      insert into calculation_details (calculation_id, answer_id, factor_id, category, activity_value, converted_value, emissions_kgco2e) values (v_calc, r.id, f.id, 'movilidad', r.numeric_value, v_conv, v_conv * f.factor_value);
      v_total := v_total + v_conv * f.factor_value;
    end if;
  end if;

  -- 4. Vuelos
  for r in select a.*, pe.valor km from activity_answers a join parametros_estimacion pe on pe.codigo = a.question_code
            where a.survey_id = p_survey and pe.grupo = 'vuelo' and a.numeric_value > 0 loop
    f := factor_vigente(case r.question_code when 'VU_NACIONAL' then 'vuelo_nacional'
                                                                  when 'VU_CORTO' then 'vuelo_corto' else 'vuelo_largo' end, v_p.end_date);
    v_conv := r.numeric_value * r.km;
    insert into calculation_details (calculation_id, answer_id, factor_id, category, activity_value, converted_value, emissions_kgco2e) values (v_calc, r.id, f.id, 'vuelos', r.numeric_value, v_conv, v_conv * f.factor_value);
    v_total := v_total + v_conv * f.factor_value;
  end loop;

  update calculations set total_kgco2e = round(v_total, 2) where id = v_calc;
  return round(v_total, 2);
end $$;

revoke execute on function public.calcular_encuesta(uuid) from public, anon;
grant  execute on function public.calcular_encuesta(uuid) to authenticated;

-- Nuevo periodo de prueba: noviembre 2026, método HV-2.0
update public.survey_periods set status = 'cerrado' where name = 'Octubre 2026';
insert into public.survey_periods (name, start_date, end_date, methodology_version, status)
values ('Noviembre 2026', '2026-11-01', '2026-11-30', 'HV-2.0', 'abierto')
on conflict (name) do update set status = 'abierto', methodology_version = 'HV-2.0';
