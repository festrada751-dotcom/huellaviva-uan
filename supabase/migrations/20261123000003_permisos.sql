-- HuellaViva UAN · Migración 3: permisos explícitos (GRANT)
-- Los proyectos nuevos de Supabase ya no dan permisos automáticos a los roles anon y authenticated.
-- Aquí se conceden solo los mínimos; RLS sigue decidiendo QUÉ filas ve cada usuario.

grant usage on schema public to anon, authenticated;

-- Aviso de privacidad visible para cualquiera (también sin sesión)
grant select on public.consent_versions to anon, authenticated;
drop policy if exists consent_vers_lectura on public.consent_versions;
create policy consent_vers_lectura on public.consent_versions for select to anon, authenticated using (true);

-- Usuario autenticado (participante o administrador; RLS filtra)
grant select, insert, update         on public.profiles            to authenticated;
grant select                         on public.user_roles          to authenticated;
grant select, insert, update         on public.consents            to authenticated;
grant select, insert, update         on public.survey_periods      to authenticated;
grant select, insert, update         on public.surveys             to authenticated;
grant select, insert, update, delete on public.activity_answers    to authenticated;
grant select, insert, update         on public.emission_factors    to authenticated;
grant select, insert, update, delete on public.tariffs             to authenticated;
grant select                         on public.calculations        to authenticated;
grant select                         on public.calculation_details to authenticated;
grant select, insert                 on public.data_requests       to authenticated;
grant select                         on public.admin_audit_log     to authenticated;

-- Funciones: solo usuarios con sesión
revoke execute on function public.calcular_encuesta(uuid)  from public, anon;
revoke execute on function public.dashboard_agregado(uuid) from public, anon;
grant  execute on function public.calcular_encuesta(uuid)  to authenticated;
grant  execute on function public.dashboard_agregado(uuid) to authenticated;
grant  execute on function public.tiene_rol(rol_app)       to authenticated;
grant  execute on function public.es_admin_ambiental()     to authenticated;
