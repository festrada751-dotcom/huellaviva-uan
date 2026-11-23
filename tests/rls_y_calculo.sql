-- HuellaViva UAN · Pruebas de RLS y cálculo (ejecutar en el SQL Editor de Supabase, como postgres,
-- DESPUÉS de las migraciones y seed.sql). Crea usuarios SINTÉTICOS y simula sus sesiones.
-- Al final muestra una tabla con 12 filas OK. Si una prueba falla, se detiene con FALLO y no queda ningún dato guardado.

begin;

-- Limpieza de ejecuciones anteriores y tabla de resultados
delete from auth.users where email like '%@ejemplo.test';
create temp table resultados (orden timestamptz default clock_timestamp(), prueba text);
grant all on resultados to anon, authenticated;

-- ---------- Usuarios sintéticos ----------
insert into auth.users (id, email) values
 ('11111111-1111-1111-1111-111111111111','participante.a@ejemplo.test'),
 ('22222222-2222-2222-2222-222222222222','participante.b@ejemplo.test'),
 ('33333333-3333-3333-3333-333333333333','admin.ambiental@ejemplo.test');
insert into public.user_roles values ('33333333-3333-3333-3333-333333333333','admin_ambiental', now());

-- Periodo abierto (Noviembre 2026, método HV-2.0)
create or replace function pg_temp.periodo() returns uuid language sql as $$
  select id from public.survey_periods where status = 'abierto' order by start_date desc limit 1 $$;

-- Helper para simular sesión
create or replace function pg_temp.como(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- ===== PS-04 / PA-01: sin consentimiento no se guarda encuesta =====
select pg_temp.como('11111111-1111-1111-1111-111111111111');
insert into public.profiles (id, tipo_usuario, campus) values (auth.uid(), 'estudiante', 'Santa Marta');
do $$ begin
  begin
    insert into public.surveys (profile_id, period_id, consent_id)
    values (auth.uid(), pg_temp.periodo(), gen_random_uuid());
    raise exception 'FALLO PS-04: se guardó encuesta sin consentimiento';
  exception when foreign_key_violation or insufficient_privilege or check_violation then
    insert into resultados(prueba) values ('OK PS-04: sin consentimiento no se guarda');
  end;
end $$;

-- Participante A acepta y responde (ejemplo trazable de la sección 5)
insert into public.consents (id, profile_id, consent_version_id)
values ('aaaaaaaa-0000-0000-0000-000000000001', auth.uid(), '00000000-0000-0000-0000-0000000000c1');
insert into public.surveys (id, profile_id, period_id, consent_id, personas_hogar, status, submitted_at)
values ('bbbbbbbb-0000-0000-0000-000000000001', auth.uid(), pg_temp.periodo(),
        'aaaaaaaa-0000-0000-0000-000000000001', 3, 'enviada', now());
insert into public.activity_answers (survey_id, category, question_code, numeric_value, text_value) values
 ('bbbbbbbb-0000-0000-0000-000000000001','electricidad','E00',null,'no'),
 ('bbbbbbbb-0000-0000-0000-000000000001','electricidad','AP_NEVERA',1,null),
 ('bbbbbbbb-0000-0000-0000-000000000001','electricidad','AP_VENTILADOR',8,null),
 ('bbbbbbbb-0000-0000-0000-000000000001','electricidad','AP_TV',4.5,null),
 ('bbbbbbbb-0000-0000-0000-000000000001','electricidad','AP_BOMBILLOS',4.5,null),
 ('bbbbbbbb-0000-0000-0000-000000000001','gas','C01',null,'glp'),
 ('bbbbbbbb-0000-0000-0000-000000000001','gas','CO_DESAYUNO',1,null),
 ('bbbbbbbb-0000-0000-0000-000000000001','gas','CO_ALMUERZO',1,null),
 ('bbbbbbbb-0000-0000-0000-000000000001','gas','CO_CENA',1,null),
 ('bbbbbbbb-0000-0000-0000-000000000001','movilidad','T01',null,'bus'),
 ('bbbbbbbb-0000-0000-0000-000000000001','movilidad','T02',5,null),
 ('bbbbbbbb-0000-0000-0000-000000000001','movilidad','T03',5,null),
 ('bbbbbbbb-0000-0000-0000-000000000001','vuelos','VU_NACIONAL',1,null);

-- ===== PC-01: cálculo del ejemplo sin recibos (método HV-2.0) =====
do $$ declare t numeric; begin
  t := public.calcular_encuesta('bbbbbbbb-0000-0000-0000-000000000001');
  if t between 203.75 and 203.85 then insert into resultados(prueba) values (format('OK PC-01: total = %s kg CO2e', t));
  else raise exception 'FALLO PC-01: total = %', t; end if;
end $$;

-- ===== PV-01: valor negativo rechazado =====
do $$ begin
  begin
    insert into public.activity_answers (survey_id, category, question_code, numeric_value)
    values ('bbbbbbbb-0000-0000-0000-000000000001','vuelos','VU_CORTO',-3);
    raise exception 'FALLO PV-01';
  exception when check_violation then insert into resultados(prueba) values ('OK PV-01: valor negativo rechazado'); end;
end $$;

-- ===== PS-02: participante no puede darse rol de administrador =====
do $$ begin
  begin
    insert into public.user_roles values (auth.uid(), 'admin_ambiental', now());
    raise exception 'FALLO PS-02';
  exception when insufficient_privilege then insert into resultados(prueba) values ('OK PS-02: no puede autoasignarse rol'); end;
end $$;

-- ===== PS-03: participante no puede ver el dashboard =====
do $$ begin
  if (select count(*) from public.dashboard_agregado()) = 0 then insert into resultados(prueba) values ('OK PS-03: participante no ve agregados');
  else raise exception 'FALLO PS-03'; end if;
end $$;

-- ===== PC-03: participante no puede crear factores =====
do $$ begin
  begin
    insert into public.emission_factors (code, version, category, activity, factor_value, unit_activity, geography, source, source_url, reference_year, valid_from)
    values ('FE-X',1,'movilidad','bus',0,'km','x','x','x',2026,'2026-01-01');
    raise exception 'FALLO PC-03';
  exception when insufficient_privilege then insert into resultados(prueba) values ('OK PC-03: participante no edita factores'); end;
end $$;
reset role;

-- ===== PS-01: participante B no ve datos de A =====
select pg_temp.como('22222222-2222-2222-2222-222222222222');
insert into public.profiles (id, tipo_usuario) values (auth.uid(), 'profesor');
do $$ begin
  if (select count(*) from public.surveys) = 0 and (select count(*) from public.activity_answers) = 0
     and (select count(*) from public.calculations) = 0 and (select count(*) from public.profiles) = 1
  then insert into resultados(prueba) values ('OK PS-01: B no ve filas de A');
  else raise exception 'FALLO PS-01'; end if;
end $$;
reset role;

-- ===== Usuario no autorizado (anon) =====
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
do $$ begin
  begin
    if (select count(*) from public.surveys) = 0 and (select count(*) from public.profiles) = 0
    then insert into resultados(prueba) values ('OK PS-06: anónimo no ve datos (0 filas)');
    else raise exception 'FALLO PS-06'; end if;
  exception when insufficient_privilege then
    insert into resultados(prueba) values ('OK PS-06: anónimo no ve datos (acceso denegado)');
  end;
end $$;
reset role;

-- ===== PC-04 (CR-04): con recibo de luz y gas natural real =====
select pg_temp.como('22222222-2222-2222-2222-222222222222');
insert into public.consents (id, profile_id, consent_version_id)
values ('aaaaaaaa-0000-0000-0000-000000000002', auth.uid(), '00000000-0000-0000-0000-0000000000c1');
insert into public.surveys (id, profile_id, period_id, consent_id, personas_hogar, status)
values ('bbbbbbbb-0000-0000-0000-000000000002', auth.uid(), pg_temp.periodo(),
        'aaaaaaaa-0000-0000-0000-000000000002', 2, 'enviada');
insert into public.activity_answers (survey_id, category, question_code, numeric_value, text_value) values
 ('bbbbbbbb-0000-0000-0000-000000000002','electricidad','E00',null,'si'),
 ('bbbbbbbb-0000-0000-0000-000000000002','electricidad','E01',200,null),
 ('bbbbbbbb-0000-0000-0000-000000000002','gas','C01',null,'gas_natural'),
 ('bbbbbbbb-0000-0000-0000-000000000002','gas','C02',10,null);
do $$ declare t numeric; begin
  t := public.calcular_encuesta('bbbbbbbb-0000-0000-0000-000000000002');  -- 200/2 x 0,220 = 22 + 10/2 x 1,841 = 9,205 -> 31,21
  if t = 31.21 then insert into resultados(prueba) values (format('OK PC-04: con recibos = %s kg CO2e (dato medido, no estimado)', t));
  else raise exception 'FALLO PC-04: %', t; end if;
end $$;
reset role;

-- ===== Datos sintéticos para el dashboard: 12 estudiantes + 7 administrativos =====
do $$ declare i int; u uuid; c uuid; s uuid; begin
  for i in 1..19 loop
    u := gen_random_uuid();
    insert into auth.users (id, email) values (u, 'sintetico'||i||'@ejemplo.test');
    insert into public.profiles values (u, (case when i <= 12 then 'estudiante' else 'administrativo' end)::tipo_usuario, 'Santa Marta', 'activo', now());
    insert into public.consents (profile_id, consent_version_id) values (u, '00000000-0000-0000-0000-0000000000c1') returning id into c;
    insert into public.surveys (profile_id, period_id, consent_id, personas_hogar, status)
      values (u, pg_temp.periodo(), c, 1 + i % 4, 'enviada') returning id into s;
    insert into public.activity_answers (survey_id, category, question_code, numeric_value, unit)
      values (s, 'electricidad', 'E01', 80 + i * 10, 'kWh');
    perform set_config('request.jwt.claims', json_build_object('sub', u)::text, true);
    perform public.calcular_encuesta(s);
  end loop;
end $$;

-- ===== PS-03 / PA-03: el administrador ve agregados y los grupos < 10 se ocultan =====
select pg_temp.como('33333333-3333-3333-3333-333333333333');
do $$ begin
  if exists (select 1 from public.dashboard_agregado() where tipo_usuario = 'estudiante' and n_participantes >= 10)
     and not exists (select 1 from public.dashboard_agregado() where tipo_usuario = 'administrativo')
  then insert into resultados(prueba) values ('OK PA-03: admin ve estudiantes (n>=10) y se oculta administrativos (n=7)');
  else raise exception 'FALLO PA-03'; end if;
  if (select count(*) from public.surveys) = 0 then insert into resultados(prueba) values ('OK PS-05: admin no lee filas individuales');
  else raise exception 'FALLO PS-05'; end if;
end $$;

-- ===== PC-02: un factor usado no se puede sobrescribir =====
do $$ begin
  begin
    update public.emission_factors set factor_value = 0.5 where code = 'FE-ELE-01';
    raise exception 'FALLO PC-02';
  exception when raise_exception then
    if sqlerrm like 'FALLO%' then raise; end if;
    insert into resultados(prueba) values (format('OK PC-02: factor protegido (%s)', sqlerrm));
  end;
end $$;
reset role;

-- Borrar los datos sintéticos y mostrar resultados
delete from auth.users where email like '%@ejemplo.test';
commit;
select prueba as resultado from resultados order by orden;
