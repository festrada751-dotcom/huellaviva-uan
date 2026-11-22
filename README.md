# HuellaViva UAN

Estimador académico de la huella de carbono mensual (kg CO₂e) de estudiantes, profesores y administrativos de la Universidad Antonio Nariño.
Trabajo final integrador de **Gestión de Requisitos** y **Mecanismos de Persistencia de Software** (2026).

> **Advertencia académica.** Es un estimador educativo y de diagnóstico. No es un inventario institucional verificado, una certificación, una compensación de emisiones ni un registro RENARE. El repositorio solo contiene datos sintéticos.

- Documento de análisis y diseño: `docs/HuellaViva_Analisis_y_Diseno.pdf`
- Demo: [URL de Vercel]
- Autor: [Nombre completo] · Roles Scrum: Product Owner, Scrum Master y Developer

## Qué hace

| Perfil | Puede |
| --- | --- |
| Participante | Aceptar el consentimiento, responder la encuesta (electricidad, gas, movilidad, vuelos), ver su informe, pedir corrección o supresión |
| Administrador ambiental | Ver el dashboard agregado (solo grupos con ≥ 10 respuestas), exportar CSV, crear versiones de factores, abrir y cerrar periodos |
| Anónimo | Ver la página de inicio y el aviso de privacidad |

Cálculo: `emisiones = dato de actividad convertido × factor de emisión`. Cada línea guarda el factor usado, así cualquier cifra se puede reconstruir.

## Tecnología

- Frontend: HTML, CSS y JavaScript (módulos ES) + `@supabase/supabase-js` 2, sin build.
- Backend: Supabase (Auth + PostgreSQL 15+) con Row Level Security en todas las tablas.
- Despliegue: Vercel (sitio estático, carpeta `src/`).

## Estructura

```
├── README.md
├── .env.example            # nombres de variables, sin valores
├── .gitignore
├── docs/                   # documento, ERD (erd.md), wireframes
├── src/                    # index.html, app.js, styles.css, config.example.js, icono.svg
├── supabase/
│   ├── migrations/         # esquema, RLS, funciones
│   └── seed.sql            # aviso, periodo, tarifa y factores (sintético)
├── tests/rls_y_calculo.sql # 12 pruebas de RLS, cálculo y validación
└── assets/                 # ícono
```

## Instalación (≈ 20 minutos)

1. Cree un proyecto gratuito en [supabase.com](https://supabase.com).
2. En **SQL Editor** ejecute en este orden:
   1. `supabase/migrations/20261123000001_esquema_inicial.sql`
   2. `supabase/migrations/20261123000002_rls_y_vistas.sql`
   3. `supabase/migrations/20261123000003_permisos.sql` (los proyectos nuevos de Supabase no dan permisos automáticos)
   4. `supabase/seed.sql`
3. Ejecute `tests/rls_y_calculo.sql`. En **Messages** deben aparecer 12 líneas `OK`. El script revierte todo al final.
4. Copie `src/config.example.js` como `src/config.js` y pegue **Project URL** y la clave **anon public** (Settings → API).
   **Nunca** use la clave `service_role` en el navegador ni la suba a GitHub.
5. Ejecute localmente con un servidor estático, por ejemplo: `npx serve src` o la extensión *Live Server* de VS Code.
6. Regístrese en la app. Para volverse administrador, en SQL Editor:
   ```sql
   insert into public.user_roles (user_id, rol)
   select id, 'admin_ambiental' from auth.users where email = 'su-correo@ejemplo.com';
   ```
7. (Opcional) Para pruebas rápidas desactive la confirmación por correo en Authentication → Providers → Email.

### Desplegar en Vercel

Importe el repositorio, en *Root Directory* elija `src` y en *Framework Preset* "Other". Como `config.js` no se sube a GitHub, créelo en el despliegue
o, para la demo académica, súbalo solo con la clave anon (es pública por diseño y la protege RLS).

## Variables

| Variable | Dónde | Secreto |
| --- | --- | --- |
| `SUPABASE_URL` | `src/config.js` | No |
| `SUPABASE_ANON_KEY` | `src/config.js` | No (protegida por RLS) |
| `service_role` | Solo panel de Supabase | **Sí. Nunca en el código** |

## Factores de emisión (v1, cargados el 21/11/2026)

| Código | Actividad | Valor | Fuente |
| --- | --- | --- | --- |
| FE-ELE-01 | Electricidad SIN | 0,220 kg CO₂e/kWh | UPME, Resolución 000085 de 2026 (año 2024) |
| FE-GLP-01 | GLP (Cartagena) | 3,0513 kg CO₂e/kg | UPME, calculadora FECOC (consultada 21/11/2026) |
| FE-GN-01 | Gas natural (Guajira) | 1,8410 kg CO₂e/m³ | UPME, calculadora FECOC (consultada 21/11/2026) |
| FE-CAR-01 | Carro gasolina | 0,16152 kg CO₂e/km | DESNZ/DEFRA 2026 |
| FE-BUS-01 | Bus | 0,1305 kg CO₂e/pkm | DESNZ/DEFRA 2025 |
| FE-MOT-01 | Moto | 0,11367 kg CO₂e/km | DEFRA 2023 (provisional) |
| FE-VNA-01 | Vuelo nacional (RF) | 0,22928 kg CO₂e/pkm | DESNZ/DEFRA 2026 |
| FE-VIC-01 | Vuelo internacional corto (RF) | 0,12576 kg CO₂e/pkm | DESNZ/DEFRA 2026 |
| FE-VIL-01 | Vuelo internacional largo (RF) | 0,11704 kg CO₂e/pkm | DESNZ/DEFRA 2026 |

Tarifas para estimar kWh desde la factura (CR-01): Air-e, octubre 2026, por estrato (air-e.com/tarifas).

## Limitaciones

Factores de transporte del Reino Unido; distancias por rangos; no incluye alimentación, bienes ni residuos; la muestra no representa a toda la UAN; el aviso de privacidad es un borrador que debe validar la universidad.

## Licencia

Código bajo licencia MIT con fines académicos. El ícono es un diseño propio. Las fuentes de factores pertenecen a sus autores (UPME, DESNZ).
