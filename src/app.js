// HuellaViva UAN · aplicación de una sola página (HTML + JS + supabase-js)
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';
import { vistaEncuesta, vistaInforme } from './encuesta.js';

const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
const app = document.getElementById('app');
const menu = document.getElementById('menu');

const estado = { user: null, perfil: null, esAdmin: false, periodo: null, consent: null };

// ---------- utilidades ----------
const h = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const kg = (n) => Number(n ?? 0).toLocaleString('es-CO', { maximumFractionDigits: 1 });
const pintar = (html) => { app.innerHTML = html; app.focus(); };
const valor = (id) => document.getElementById(id)?.value?.trim() ?? '';
const num = (id) => (valor(id) === '' ? null : Number(valor(id)));
function mensaje(id, texto, tipo = 'error') { const el = document.getElementById(id); if (el) { el.className = tipo; el.textContent = texto; } }

const CAT_NOMBRE = { electricidad: 'Electricidad', gas: 'Gas del hogar', movilidad: 'Movilidad', vuelos: 'Vuelos' };

// ---------- sesión ----------
async function cargarSesion() {
  const { data: { session } } = await sb.auth.getSession();
  estado.user = session?.user ?? null;
  estado.perfil = null; estado.esAdmin = false; estado.consent = null;
  if (estado.user) {
    const [p, r, c] = await Promise.all([
      sb.from('profiles').select('*').eq('id', estado.user.id).maybeSingle(),
      sb.from('user_roles').select('rol').eq('user_id', estado.user.id),
      sb.from('consents').select('*').is('revoked_at', null).order('accepted_at', { ascending: false }).limit(1),
    ]);
    estado.perfil = p.data; estado.esAdmin = (r.data ?? []).some((x) => x.rol === 'admin_ambiental');
    estado.consent = c.data?.[0] ?? null;
  }
  estado.periodo = null;
  if (estado.user) {
    const per = await sb.from('survey_periods').select('*').eq('status', 'abierto').order('start_date', { ascending: false }).limit(1);
    estado.periodo = per.data?.[0] ?? null;
  }
  pintarMenu();
}

function pintarMenu() {
  const links = [['#inicio', 'Inicio']];
  if (estado.user) {
    links.push(['#encuesta', 'Encuesta'], ['#informe', 'Mi huella'], ['#misdatos', 'Mis datos']);
    if (estado.esAdmin) links.push(['#dashboard', 'Dashboard'], ['#factores', 'Factores'], ['#periodos', 'Periodos']);
  } else links.push(['#acceso', 'Ingresar']);
  menu.innerHTML = links.map(([href, t]) => `<a href="${href}">${t}</a>`).join('') +
    (estado.user ? '<button id="salir" type="button">Salir</button>' : '');
  document.getElementById('salir')?.addEventListener('click', async () => { await sb.auth.signOut(); location.hash = '#inicio'; });
}

// ---------- vistas ----------
const vistas = {
  inicio() {
    pintar(`<h1>Conozca su huella de carbono mensual</h1>
      <div class="tarjeta"><p>HuellaViva estima cuántos kg de CO₂ equivalente generan sus actividades de un mes:
      electricidad, gas del hogar, movilidad al campus y vuelos. Recibe un informe con fuentes y recomendaciones;
      la universidad solo ve promedios de grupos de 10 o más personas.</p>
      <p>Son unas 12 preguntas rápidas, tocando tarjetas: unos 3 minutos. No necesitas recibos y no pedimos documento, dirección ni placa.</p>
      <a class="boton" href="${estado.user ? '#encuesta' : '#acceso'}">Participar</a>
      <a class="boton secundario" href="#privacidad">Aviso de privacidad</a></div>`);
  },

  async privacidad() {
    const { data } = await sb.from('consent_versions').select('*').eq('active', true).maybeSingle();
    pintar(`<h1>Aviso de privacidad</h1><div class="tarjeta"><p class="ayuda">Versión ${h(data?.version ?? '—')} · vigente desde ${h(data?.valid_from ?? '—')}</p>
      <p>${h(data?.texto ?? 'Inicie sesión para ver el aviso vigente.')}</p>
      <p class="ayuda">Responsable, canal de contacto y política institucional: [por completar con la UAN].</p></div>`);
  },

  acceso() {
    pintar(`<h1>Ingresar</h1><form id="f" class="tarjeta">
      <label for="email">Correo</label><input id="email" type="email" autocomplete="email" required>
      <label for="clave">Contraseña <span class="ayuda">(mínimo 8 caracteres)</span></label>
      <input id="clave" type="password" minlength="8" autocomplete="current-password" required>
      <button class="boton" type="submit">Ingresar</button>
      <button class="boton secundario" type="button" id="registro">Crear cuenta</button>
      <p id="msg" role="alert"></p></form>`);
    const entrar = async (registro) => {
      const email = valor('email'), password = valor('clave');
      if (!email || password.length < 8) return mensaje('msg', 'Escriba un correo y una contraseña de al menos 8 caracteres.');
      const { error } = registro ? await sb.auth.signUp({ email, password }) : await sb.auth.signInWithPassword({ email, password });
      if (error) return mensaje('msg', error.message);
      await cargarSesion();
      if (registro && !estado.user) return mensaje('msg', 'Revise su correo para confirmar la cuenta y luego ingrese.', 'ok');
      location.hash = '#encuesta';
    };
    document.getElementById('f').addEventListener('submit', (e) => { e.preventDefault(); entrar(false); });
    document.getElementById('registro').addEventListener('click', () => entrar(true));
  },

  async consentimiento() {
    const { data: v } = await sb.from('consent_versions').select('*').eq('active', true).maybeSingle();
    if (!v) return pintar('<p class="error">No hay un aviso de consentimiento activo.</p>');
    pintar(`<h1>Antes de empezar</h1><div class="tarjeta">
      <p><strong>Para qué:</strong> ${h(v.purpose)}. <strong>Periodo:</strong> ${h(estado.periodo?.name ?? 'sin periodo abierto')}.</p>
      <div class="consentimiento" tabindex="0">${h(v.texto)}</div>
      <p class="ayuda">Versión ${h(v.version)} · ${h(v.valid_from)}</p>
      <label><input type="checkbox" id="acepto" style="width:auto"> He leído el aviso y acepto participar</label>
      <button class="boton" id="continuar" type="button">Continuar</button>
      <a class="boton secundario" href="#inicio">Cancelar</a><p id="msg" role="alert"></p></div>`);
    document.getElementById('continuar').addEventListener('click', async () => {
      if (!document.getElementById('acepto').checked) return mensaje('msg', 'Debe aceptar el aviso para continuar. Si cancela, no se guarda nada.');
      const { data, error } = await sb.from('consents').insert({ profile_id: estado.user.id, consent_version_id: v.id }).select().single();
      if (error) return mensaje('msg', error.message);
      estado.consent = data; location.hash = '#encuesta';
    });
  },

  async perfil() {
    pintar(`<h1>Su grupo</h1><form id="f" class="tarjeta">
      <label for="tipo">¿A qué grupo pertenece? *</label>
      <select id="tipo" required><option value="">Elija…</option><option value="estudiante">Estudiante</option>
      <option value="profesor">Profesor</option><option value="administrativo">Administrativo</option></select>
      <label for="campus">Campus <span class="ayuda">(opcional)</span></label>
      <input id="campus" placeholder="Ej.: Santa Marta" maxlength="60">
      <button class="boton" type="submit">Guardar</button><p id="msg" role="alert"></p></form>`);
    document.getElementById('f').addEventListener('submit', async (e) => {
      e.preventDefault();
      if (!valor('tipo')) return mensaje('msg', 'Elija su grupo.');
      const { error } = await sb.from('profiles').upsert({ id: estado.user.id, tipo_usuario: valor('tipo'), campus: valor('campus') || null });
      if (error) return mensaje('msg', error.message);
      await cargarSesion(); location.hash = '#encuesta';
    });
  },

  async encuesta() {
    if (!estado.user) return (location.hash = '#acceso');
    if (!estado.perfil) return (location.hash = '#perfil');
    if (!estado.consent) return (location.hash = '#consentimiento');
    if (!estado.periodo) return pintar('<h1>Encuesta</h1><p class="tarjeta">No hay un periodo abierto en este momento.</p>');
    const { data: previa } = await sb.from('surveys').select('*, activity_answers(*)').eq('period_id', estado.periodo.id).maybeSingle();
    await vistaEncuesta({ sb, estado, app, previa, irA: (r) => { location.hash = r; } });
  },

  async informe() {
    if (!estado.user) return (location.hash = '#acceso');
    await vistaInforme({ sb, app });
  },

  async misdatos() {
    if (!estado.user) return (location.hash = '#acceso');
    const { data: sol } = await sb.from('data_requests').select('*').order('created_at', { ascending: false });
    pintar(`<h1>Mis datos</h1>
      <div class="tarjeta"><p>Grupo: <strong>${h(estado.perfil?.tipo_usuario ?? '—')}</strong> · Campus: ${h(estado.perfil?.campus ?? '—')}</p>
      <a class="boton secundario" href="#perfil">Cambiar grupo</a> <a class="boton secundario" href="#encuesta">Editar encuesta</a>
      <button class="boton secundario" id="revocar" type="button">Retirar mi consentimiento</button></div>
      <form id="f" class="tarjeta"><h2>Solicitar corrección, supresión o consulta</h2>
      <label for="tipo">Tipo</label><select id="tipo"><option value="correccion">Corrección</option><option value="supresion">Supresión</option><option value="consulta">Consulta</option></select>
      <label for="detalle">Detalle <span class="ayuda">(máx. 500 caracteres; no incluya datos sensibles)</span></label><textarea id="detalle" maxlength="500" rows="3"></textarea>
      <button class="boton" type="submit">Enviar solicitud</button><p id="msg" role="alert"></p>
      <p class="ayuda">Canal institucional: [por completar con la UAN].</p></form>
      <div class="tarjeta"><h2>Mis solicitudes</h2>${sol?.length ? `<table><thead><tr><th>Fecha</th><th>Tipo</th><th>Estado</th></tr></thead><tbody>
      ${sol.map((s) => `<tr><td>${new Date(s.created_at).toLocaleDateString('es-CO')}</td><td>${h(s.tipo)}</td><td>${h(s.estado)}</td></tr>`).join('')}</tbody></table>` : '<p>No tiene solicitudes.</p>'}</div>`);
    document.getElementById('f').addEventListener('submit', async (e) => {
      e.preventDefault();
      const { error } = await sb.from('data_requests').insert({ profile_id: estado.user.id, tipo: valor('tipo'), detalle: valor('detalle') || null });
      if (error) return mensaje('msg', error.message); vistas.misdatos();
    });
    document.getElementById('revocar').addEventListener('click', async () => {
      if (!estado.consent) return;
      await sb.from('consents').update({ revoked_at: new Date().toISOString() }).eq('id', estado.consent.id);
      await cargarSesion(); location.hash = '#inicio';
    });
  },

  async dashboard() {
    if (!estado.esAdmin) return pintar('<p class="error">Acceso solo para administradores autorizados.</p>');
    const { data: periodos } = await sb.from('survey_periods').select('id, name').order('start_date', { ascending: false });
    const sel = new URLSearchParams(location.hash.split('?')[1] ?? '').get('p') ?? '';
    const { data: filas, error } = await sb.rpc('dashboard_agregado', { p_period: sel || null });
    if (error) return pintar(`<p class="error">${h(error.message)}</p>`);
    const n = new Set((filas ?? []).map((f) => `${f.periodo}|${f.tipo_usuario}|${f.campus}`));
    const porCat = {}; (filas ?? []).forEach((f) => { porCat[f.categoria] = (porCat[f.categoria] ?? 0) + Number(f.promedio_kg); });
    pintar(`<h1>Dashboard agregado</h1>
      <div class="tarjeta"><label for="per">Periodo</label><select id="per"><option value="">Todos</option>
      ${(periodos ?? []).map((p) => `<option value="${p.id}" ${p.id === sel ? 'selected' : ''}>${h(p.name)}</option>`).join('')}</select>
      <p class="ayuda">Solo se muestran grupos (periodo × grupo × campus × categoría) con 10 o más respuestas. Regla de diseño del proyecto, no umbral legal.
      Los resultados describen la muestra que respondió; no se extrapolan a toda la UAN.</p>
      <p>Grupos publicables: <strong>${n.size}</strong></p>
      <button class="boton secundario" id="csv" type="button">Descargar CSV agregado</button></div>
      <div class="tarjeta"><h2>Promedio por categoría (suma de grupos visibles)</h2><div class="barras">
      ${Object.entries(porCat).map(([c, v]) => `<div class="barra-cat"><span>${CAT_NOMBRE[c]}</span><div class="relleno" style="width:${(v / Math.max(...Object.values(porCat))) * 100}%"></div><span>${kg(v)} kg</span></div>`).join('') || '<p>Sin grupos con 10 o más respuestas.</p>'}</div></div>
      <div class="tarjeta tabla-scroll"><table><thead><tr><th>Periodo</th><th>Grupo</th><th>Campus</th><th>Categoría</th><th>n</th><th>Promedio kg</th><th>Mediana kg</th></tr></thead><tbody>
      ${(filas ?? []).map((f) => `<tr><td>${h(f.periodo)}</td><td>${h(f.tipo_usuario)}</td><td>${h(f.campus)}</td><td>${CAT_NOMBRE[f.categoria]}</td><td>${f.n_participantes}</td><td>${kg(f.promedio_kg)}</td><td>${kg(f.mediana_kg)}</td></tr>`).join('')}</tbody></table></div>`);
    document.getElementById('per').addEventListener('change', (e) => { location.hash = `#dashboard?p=${e.target.value}`; });
    document.getElementById('csv').addEventListener('click', () => {
      const cab = ['periodo', 'grupo', 'campus', 'categoria', 'n', 'promedio_kgco2e', 'mediana_kgco2e'];
      const csv = [cab.join(','), ...(filas ?? []).map((f) => [f.periodo, f.tipo_usuario, f.campus, f.categoria, f.n_participantes, f.promedio_kg, f.mediana_kg].map((x) => `"${String(x).replace(/"/g, '""')}"`).join(','))].join('\n');
      const a = Object.assign(document.createElement('a'), { href: URL.createObjectURL(new Blob(['﻿' + csv], { type: 'text/csv' })), download: 'huellaviva_agregado.csv' });
      a.click();
    });
  },

  async factores() {
    if (!estado.esAdmin) return pintar('<p class="error">Acceso solo para administradores autorizados.</p>');
    const { data: fs } = await sb.from('emission_factors').select('*').order('code').order('version', { ascending: false });
    pintar(`<h1>Factores de emisión</h1>
      <div class="tarjeta tabla-scroll"><table><thead><tr><th>Código</th><th>v</th><th>Actividad</th><th>Valor</th><th>Fuente</th><th>Año</th><th>Vigencia</th><th>Estado</th></tr></thead><tbody>
      ${(fs ?? []).map((f) => `<tr><td>${h(f.code)}</td><td>${f.version}</td><td>${h(f.activity)}</td><td>${Number(f.factor_value).toLocaleString('es-CO', { maximumFractionDigits: 5 })} kg/${h(f.unit_activity)}</td>
      <td><a href="${h(f.source_url)}" target="_blank" rel="noopener">${h(f.source)}</a></td><td>${f.reference_year}</td><td>${h(f.valid_from)} → ${h(f.valid_to ?? 'hoy')}</td><td>${h(f.status)}</td></tr>`).join('')}</tbody></table></div>
      <form id="f" class="tarjeta"><h2>Nueva versión de un factor</h2><p class="ayuda">Un factor nunca se edita: se cierra el anterior y se crea una versión nueva. Todo queda en la auditoría.</p>
      <div class="fila"><div><label for="code">Código</label><select id="code">${[...new Set((fs ?? []).map((f) => f.code))].map((c) => `<option>${h(c)}</option>`).join('')}</select></div>
      <div><label for="val">Nuevo valor (kg CO₂e por unidad)</label><input id="val" type="number" step="any" min="0" required></div>
      <div><label for="anio">Año de referencia</label><input id="anio" type="number" min="1990" max="2100" required></div>
      <div><label for="desde">Vigente desde</label><input id="desde" type="date" required></div></div>
      <label for="fuente">Fuente</label><input id="fuente" required><label for="url">URL de la fuente</label><input id="url" type="url" required>
      <label for="just">Justificación del cambio</label><textarea id="just" rows="2" required></textarea>
      <button class="boton" type="submit">Crear versión</button><p id="msg" role="alert"></p></form>`);
    document.getElementById('f').addEventListener('submit', async (e) => {
      e.preventDefault();
      const ant = fs.find((f) => f.code === valor('code') && !f.valid_to) ?? fs.find((f) => f.code === valor('code'));
      if (!valor('val') || !valor('anio') || !valor('desde') || !valor('fuente') || !valor('url') || !valor('just')) return mensaje('msg', 'Complete todos los campos.');
      const cierre = new Date(new Date(valor('desde')).getTime() - 86400000).toISOString().slice(0, 10);
      const up = await sb.from('emission_factors').update({ valid_to: cierre }).eq('id', ant.id);
      if (up.error) return mensaje('msg', up.error.message);
      const nuevo = { ...ant, id: undefined, loaded_at: undefined, valid_to: null, version: Math.max(...fs.filter((f) => f.code === ant.code).map((f) => f.version)) + 1,
        factor_value: Number(valor('val')), reference_year: Number(valor('anio')), valid_from: valor('desde'), source: valor('fuente'), source_url: valor('url'),
        method: valor('just'), status: 'aprobado', approved_by: estado.user.id };
      delete nuevo.id; delete nuevo.loaded_at;
      const { error } = await sb.from('emission_factors').insert(nuevo);
      if (error) return mensaje('msg', error.message); vistas.factores();
    });
  },

  async periodos() {
    if (!estado.esAdmin) return pintar('<p class="error">Acceso solo para administradores autorizados.</p>');
    const { data: ps } = await sb.from('survey_periods').select('*').order('start_date', { ascending: false });
    pintar(`<h1>Periodos</h1><div class="tarjeta tabla-scroll"><table><thead><tr><th>Nombre</th><th>Desde</th><th>Hasta</th><th>Método</th><th>Estado</th><th></th></tr></thead><tbody>
      ${(ps ?? []).map((p) => `<tr><td>${h(p.name)}</td><td>${h(p.start_date)}</td><td>${h(p.end_date)}</td><td>${h(p.methodology_version)}</td><td>${h(p.status)}</td>
      <td>${p.status !== 'abierto' ? `<button class="boton secundario" data-id="${p.id}" data-s="abierto">Abrir</button>` : `<button class="boton secundario" data-id="${p.id}" data-s="cerrado">Cerrar</button>`}</td></tr>`).join('')}</tbody></table></div>
      <form id="f" class="tarjeta"><h2>Nuevo periodo</h2><div class="fila">
      <div><label for="nom">Nombre</label><input id="nom" placeholder="Noviembre 2026" required></div>
      <div><label for="ini">Inicio</label><input id="ini" type="date" required></div><div><label for="fin">Fin</label><input id="fin" type="date" required></div>
      <div><label for="met">Versión del método</label><input id="met" value="HV-1.1" required></div></div>
      <button class="boton" type="submit">Crear</button><p id="msg" role="alert"></p></form>`);
    app.querySelectorAll('button[data-id]').forEach((b) => b.addEventListener('click', async () => {
      const { error } = await sb.from('survey_periods').update({ status: b.dataset.s }).eq('id', b.dataset.id);
      if (error) alertaConsola(error); await cargarSesion(); vistas.periodos();
    }));
    document.getElementById('f').addEventListener('submit', async (e) => {
      e.preventDefault();
      if (valor('fin') < valor('ini')) return mensaje('msg', 'La fecha final debe ser posterior a la inicial.');
      const { error } = await sb.from('survey_periods').insert({ name: valor('nom'), start_date: valor('ini'), end_date: valor('fin'), methodology_version: valor('met') });
      if (error) return mensaje('msg', error.message); vistas.periodos();
    });
  },
};

function alertaConsola(e) { console.error(e); }

async function router() {
  const ruta = (location.hash.replace('#', '').split('?')[0]) || 'inicio';
  const privadas = ['encuesta', 'informe', 'misdatos', 'perfil', 'consentimiento', 'dashboard', 'factores', 'periodos'];
  if (privadas.includes(ruta) && !estado.user) return (location.hash = '#acceso');
  await (vistas[ruta] ?? vistas.inicio)();
}

sb.auth.onAuthStateChange(async (evento) => { if (evento === 'SIGNED_IN' || evento === 'SIGNED_OUT') { await cargarSesion(); router(); } });
window.addEventListener('hashchange', router);
await cargarSesion();
router();
