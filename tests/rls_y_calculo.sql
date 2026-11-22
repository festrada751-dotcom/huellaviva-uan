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
    values (auth.uid(), '00000000-0000-0000-0000-0000000000a1', gen_random_uuid());
    raise exception 'FALLO PS-04: se guardó encuesta sin consentimiento';
  exception when foreign_key_violation or insufficient_privilege or check_violation then
    insert into resultados(prueba) values ('OK PS-04: sin consentimiento no se guarda');
  end;
end $$;

-- Participante A acepta y responde (ejemplo trazable de la sección 5)
insert into public.consents (id, profile_id, consent_version_id)
values ('aaaaaaaa-0000-0000-0000-000000000001', auth.uid(), '00000000-0000-0000-0000-0000000000c1');
insert into public.surveys (id, profile_id, period_id, consent_id, personas_hogar, status, submitted_at)
values ('bbbbbbbb-0000-0000-0000-000000000001', auth.uid(), '00000000-0000-0000-0000-0000000000a1',
        'aaaaaaaa-0000-0000-0000-000000000001', 3, 'enviada', now());
insert into public.activity_answers (survey_id, category, question_code, tramo, numeric_value, text_value, unit) values
 ('bbbbbbbb-0000-0000-0000-000000000001','electricidad','E01',1,150,null,'kWh'),
 ('bbbbbbbb-0000-0000-0000-000000000001','gas','G01',1,null,'glp',null),
 ('bbbbbbbb-0000-0000-0000-000000000001','gas','G03',1,1,null,'cilindros'),
 ('bbbbbbbb-0000-0000-0000-000000000001','gas','G04',1,40,null,'lb'),
 ('bbbbbbbb-0000-0000-0000-000000000001','movilidad','T01',1,20,null,'dias'),
 ('bbbbbbbb-0000-0000-0000-000000000001','movilidad','T02',1,null,'bus',null),
 ('bbbbbbbb-0000-0000-0000-000000000001','movilidad','T03',1,7.5,null,'km ida y vuelta'),
 ('bbbbbbbb-0000-0000-0000-000000000001','vuelos','V01',1,1,null,'trayectos');

-- ===== PC-01: cálculo del ejemplo = 209,52 kg CO2e =====
do $$ declare t numeric; begin
  t := public.calcular_encuesta('bbbbbbbb-0000-0000-0000-000000000001');
  if t between 209.4 and 209.6 then insert into resultados(prueba) values (format('OK PC-01: total = %s kg CO2e', t));
  else raise exception 'FALLO PC-01: total = %', t; end if;
end $$;

-- ===== PV-01: valor negativo rechazado =====
do $$ begin
  begin
    insert into public.activity_answers (survey_id, category, question_code, tramo, numeric_value)
    values ('bbbbbbbb-0000-0000-0000-000000000001','vuelos','V02',1,-3);
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

-- ===== PC-04 (CR-01): estimación por factura =====
select pg_temp.como('22222222-2222-2222-2222-222222222222');
insert into public.consents (id, profile_id, consent_version_id)
values ('aaaaaaaa-0000-0000-0000-000000000002', auth.uid(), '00000000-0000-0000-0000-0000000000c1');
insert into public.surveys (id, profile_id, period_id, consent_id, personas_hogar, status)
values ('bbbbbbbb-0000-0000-0000-000000000002', auth.uid(), '00000000-0000-0000-0000-0000000000a1',
        'aaaaaaaa-0000-0000-0000-000000000002', 2, 'enviada');
insert into public.activity_answers (survey_id, category, question_code, numeric_value, unit)
values ('bbbbbbbb-0000-0000-0000-000000000002','electricidad','E02',120000,'COP');
update public.activity_answers set text_value = '2' where survey_id = 'bbbbbbbb-0000-0000-0000-000000000002' and question_code = 'E02';
do $$ declare t numeric; begin
  t := public.calcular_encuesta('bbbbbbbb-0000-0000-0000-000000000002');  -- estrato 2: 120.000 / 694,06 = 172,9 kWh / 2 x 0,220 = 19,02
  if t = 19.02 and exists (select 1 from public.activity_answers where question_code='E01' and is_estimated)
  then insert into resultados(prueba) values (format('OK PC-04: factura estimada = %s kg CO2e (marcada como estimada)', t));
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
      values (u, '00000000-0000-0000-0000-0000000000a1', c, 1 + i % 4, 'enviada') returning id into s;
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
