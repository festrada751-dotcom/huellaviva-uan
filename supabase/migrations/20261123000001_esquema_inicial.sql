-- HuellaViva UAN · Migración 1: esquema inicial
-- Prototipo académico. Solo datos sintéticos.

create extension if not exists "pgcrypto";

-- ===== Tipos =====
create type tipo_usuario   as enum ('estudiante', 'profesor', 'administrativo');
create type rol_app        as enum ('admin_ambiental', 'admin_tecnico');
create type estado_periodo as enum ('borrador', 'abierto', 'cerrado');
create type estado_encuesta as enum ('borrador', 'enviada', 'retirada');
create type categoria      as enum ('electricidad', 'gas', 'movilidad', 'vuelos');
create type estado_factor  as enum ('aprobado', 'provisional', 'pendiente', 'retirado');
create type tipo_solicitud as enum ('correccion', 'supresion', 'consulta');
create type estado_solicitud as enum ('recibida', 'en_tramite', 'atendida');

-- ===== Perfil mínimo (sin documento, dirección ni teléfono) =====
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  tipo_usuario  tipo_usuario not null,
  campus        text,
  estado        text not null default 'activo' check (estado in ('activo','inactivo')),
  created_at    timestamptz not null default now()
);

-- Roles administrativos: tabla aparte, el usuario NO puede escribirla
create table public.user_roles (
  user_id    uuid references auth.users(id) on delete cascade,
  rol        rol_app not null,
  granted_at timestamptz not null default now(),
  primary key (user_id, rol)
);

-- ===== Consentimiento =====
create table public.consent_versions (
  id          uuid primary key default gen_random_uuid(),
  version     text not null unique,
  texto       text not null,
  url         text,
  purpose     text not null,
  valid_from  date not null,
  active      boolean not null default false
);
create unique index un_consent_activo on public.consent_versions (active) where active;

create table public.consents (
  id                  uuid primary key default gen_random_uuid(),
  profile_id          uuid not null references public.profiles(id) on delete cascade,
  consent_version_id  uuid not null references public.consent_versions(id),
  accepted_at         timestamptz not null default now(),
  revoked_at          timestamptz,
  check (revoked_at is null or revoked_at >= accepted_at)
);
create index ix_consents_profile on public.consents(profile_id);

-- ===== Periodos y encuestas =====
create table public.survey_periods (
  id                   uuid primary key default gen_random_uuid(),
  name                 text not null unique,
  start_date           date not null,
  end_date             date not null,
  methodology_version  text not null,
  status               estado_periodo not null default 'borrador',
  check (end_date >= start_date)
);

create table public.surveys (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid not null references public.profiles(id) on delete cascade,
  period_id     uuid not null references public.survey_periods(id),
  consent_id    uuid not null references public.consents(id),
  personas_hogar int check (personas_hogar between 1 and 15),
  status        estado_encuesta not null default 'borrador',
  submitted_at  timestamptz,
  updated_at    timestamptz not null default now(),
  unique (profile_id, period_id)          -- una encuesta por persona y periodo
);
create index ix_surveys_period on public.surveys(period_id);

create table public.activity_answers (
  id             uuid primary key default gen_random_uuid(),
  survey_id      uuid not null references public.surveys(id) on delete cascade,
  category       categoria not null,
  question_code  text not null,            -- E01, G03, T03...
  tramo          smallint not null default 1 check (tramo between 1 and 3),
  numeric_value  numeric check (numeric_value >= 0),
  text_value     text,
  unit           text,
  is_estimated   boolean not null default false,
  unique (survey_id, question_code, tramo)
);

-- ===== Factores versionados =====
create table public.emission_factors (
  id             uuid primary key default gen_random_uuid(),
  code           text not null,            -- FE-ELE-01
  version        int  not null,
  category       categoria not null,
  activity       text not null,            -- 'bus', 'gasolina', 'glp'...
  factor_value   numeric not null check (factor_value >= 0),
  unit_activity  text not null,            -- kWh, km, pkm, kg
  unit_emission  text not null default 'kg CO2e',
  gas            text not null default 'CO2e',
  geography      text not null,
  source         text not null,
  source_url     text not null,
  reference_year int  not null,
  method         text,
  valid_from     date not null,
  valid_to       date,
  status         estado_factor not null default 'pendiente',
  approved_by    uuid references auth.users(id),
  loaded_at      timestamptz not null default now(),
  unique (code, version),
  check (valid_to is null or valid_to >= valid_from)
);

-- Tarifas para CR-01 (estimar kWh desde el valor de la factura)
create table public.tariffs (
  id         uuid primary key default gen_random_uuid(),
  period_id  uuid not null references public.survey_periods(id),
  operador   text not null,
  estrato    smallint check (estrato between 1 and 6),   -- null = tarifa plena (CU + COT)
  cop_kwh    numeric not null check (cop_kwh > 0),
  source     text not null,
  unique (period_id, operador, estrato)
);

-- ===== Cálculos reproducibles =====
create table public.calculations (
  id                   uuid primary key default gen_random_uuid(),
  survey_id            uuid not null references public.surveys(id) on delete cascade,
  methodology_version  text not null,
  total_kgco2e         numeric not null check (total_kgco2e >= 0),
  calculated_at        timestamptz not null default now()
);

create table public.calculation_details (
  id                uuid primary key default gen_random_uuid(),
  calculation_id    uuid not null references public.calculations(id) on delete cascade,
  answer_id         uuid references public.activity_answers(id) on delete set null,
  factor_id         uuid not null references public.emission_factors(id),
  category          categoria not null,
  activity_value    numeric not null,
  converted_value   numeric not null,
  emissions_kgco2e  numeric not null
);
create index ix_det_calc on public.calculation_details(calculation_id);

-- ===== Derechos del titular =====
create table public.data_requests (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  tipo        tipo_solicitud not null,
  detalle     text check (char_length(detalle) <= 500),
  estado      estado_solicitud not null default 'recibida',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ===== Auditoría =====
create table public.admin_audit_log (
  id          bigint generated always as identity primary key,
  actor_id    uuid references auth.users(id),
  action      text not null,
  entity      text not null,
  entity_id   uuid,
  before_json jsonb,
  after_json  jsonb,
  justificacion text,
  created_at  timestamptz not null default now()
);
