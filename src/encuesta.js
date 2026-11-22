// HuellaViva UAN · Encuesta tipo asistente (método HV-2.0, cambio CR-04)
// Una pregunta por pantalla, tarjetas para tocar, contador de huella en vivo y datos curiosos.

export const APARATOS = [
  { codigo: 'AP_NEVERA', emoji: '🧊', nombre: 'Nevera', nota: 'Siempre encendida' },
  { codigo: 'AP_AIRE', emoji: '❄️', nombre: 'Aire acondicionado' },
  { codigo: 'AP_VENTILADOR', emoji: '🌀', nombre: 'Ventilador' },
  { codigo: 'AP_TV', emoji: '📺', nombre: 'Televisor' },
  { codigo: 'AP_BOMBILLOS', emoji: '💡', nombre: 'Bombillos' },
  { codigo: 'AP_PORTATIL', emoji: '💻', nombre: 'Portátil' },
  { codigo: 'AP_PC', emoji: '🖥️', nombre: 'PC de escritorio' },
  { codigo: 'AP_MICROONDAS', emoji: '🍿', nombre: 'Microondas' },
  { codigo: 'AP_LAVADORA', emoji: '🫧', nombre: 'Lavadora' },
  { codigo: 'AP_PLANCHA', emoji: '👕', nombre: 'Plancha' },
  { codigo: 'AP_HORNO', emoji: '🍕', nombre: 'Horno eléctrico' },
  { codigo: 'AP_SECADOR', emoji: '💇', nombre: 'Secador de pelo' },
];
const HORAS_DIA = [['0.5', 'Menos de 1 h'], ['2', '1 a 3 h'], ['4.5', '3 a 6 h'], ['8', '6 a 10 h'], ['12', 'Más de 10 h']];
const HORAS_SEMANA = [['1', '1 h'], ['2.5', '2 a 3 h'], ['5', '4 a 6 h'], ['8', 'Más de 6 h']];
const COMBUSTIBLES = [
  ['gas_natural', '🔥', 'Gas natural', 'Llega por tubería'], ['glp', '🛢️', 'Pipeta', 'Gas en cilindro'],
  ['electrica', '⚡', 'Estufa eléctrica', 'Se enchufa'], ['lena', '🪵', 'Leña o carbón', ''], ['ninguno', '🥡', 'No cocinamos', 'Compramos hecho'],
];
const COMIDAS = [['CO_DESAYUNO', '☕', 'Desayuno'], ['CO_ALMUERZO', '🍲', 'Almuerzo'], ['CO_CENA', '🌙', 'Cena']];
const MEDIOS = [
  ['pie', '🚶', 'A pie'], ['bicicleta', '🚲', 'Bicicleta'], ['bus', '🚌', 'Bus o buseta'], ['moto', '🏍️', 'Moto propia'],
  ['mototaxi', '🛵', 'Mototaxi'], ['carro_gasolina', '🚗', 'Carro'], ['taxi', '🚕', 'Taxi o plataforma'],
];
const DISTANCIAS = [['0.5', 'Menos de 1 km'], ['2', '1 a 3 km'], ['5', '3 a 7 km'], ['11', '7 a 15 km'], ['20', 'Más de 15 km']];
const VUELOS = [['VU_NACIONAL', '🇨🇴', 'Dentro de Colombia', 'Ej.: Bogotá, Medellín'], ['VU_CORTO', '🌴', 'Fuera, pero cerca', 'Caribe, Panamá, EE. UU.'], ['VU_LARGO', '🌍', 'Lejos', 'Europa, Asia, Argentina']];

const h = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const n1 = (x) => Number(x).toLocaleString('es-CO', { maximumFractionDigits: 1 });

// ---------- cálculo en vivo (espejo del cálculo oficial en la base de datos) ----------
export function estimar(r, fe, pe) {
  const P = Math.max(Number(r.personas) || 1, 1), D = pe.CV_DIAS_MES ?? 30.4, S = pe.CV_SEMANAS_MES ?? 4.345;
  const out = { electricidad: 0, gas: 0, movilidad: 0, vuelos: 0 };
  const fEle = fe.electricidad_sin ?? 0;
  if (r.recibo === 'si' && r.kwh) out.electricidad = (r.kwh / P) * fEle;
  else for (const a of APARATOS) {
    if (!r.aparatos?.includes(a.codigo)) continue;
    const p = pe[a.codigo]; if (!p) continue;
    const horas = p.modo === 'fijo' ? 24 * D : p.modo === 'semana' ? (r.horas?.[a.codigo] ?? 0) * S : (r.horas?.[a.codigo] ?? 0) * D;
    out.electricidad += (p.valor / 1000) * horas / P * fEle;
  }
  if (['gas_natural', 'glp', 'electrica'].includes(r.cocina)) {
    let m3 = r.cocina === 'gas_natural' && r.reciboGas === 'si' && r.m3 ? r.m3 / P
      : (r.comidas ?? []).reduce((s, c) => s + (pe[c]?.valor ?? 0), 0) * D / 1000;
    if (r.cocina === 'gas_natural') out.gas = m3 * (fe.gas_natural ?? 0);
    if (r.cocina === 'glp') out.gas = m3 * (pe.CV_GN_A_GLP?.valor ?? 0) * (fe.glp ?? 0);
    if (r.cocina === 'electrica') out.gas = m3 * (pe.CV_GN_A_KWH?.valor ?? 0) * fEle;
  }
  if (r.medio && r.distancia && r.dias) {
    const km = r.distancia * 2 * r.dias * S / (r.medio === 'carro_gasolina' ? Math.max(r.ocupantes || 1, 1) : 1);
    out.movilidad = km * (fe[r.medio] ?? 0);
  }
  if (r.vuela === 'si') for (const [c] of VUELOS) out.vuelos += (r.vuelos?.[c] ?? 0) * (pe[c]?.valor ?? 0) * (fe[{ VU_NACIONAL: 'vuelo_nacional', VU_CORTO: 'vuelo_corto', VU_LARGO: 'vuelo_largo' }[c]] ?? 0);
  out.total = out.electricidad + out.gas + out.movilidad + out.vuelos;
  return out;
}

// ---------- pasos ----------
function pasos(fe, pe) {
  const ratioAire = pe.AP_AIRE && pe.AP_VENTILADOR ? Math.round(pe.AP_AIRE.valor / pe.AP_VENTILADOR.valor) : 11;
  const carro3 = fe.carro_gasolina && fe.bus ? Math.round((1 - fe.carro_gasolina / 3 / fe.bus) * 100) : 59;
  return [
    { id: 'personas', seccion: 'Tu casa', titulo: '¿Cuántas personas viven en tu casa?', ayuda: 'Contándote a ti. Así repartimos el consumo de la casa entre todos.', tipo: 'contador', min: 1, max: 15 },
    { id: 'recibo', seccion: 'Energía', titulo: '¿Tienes a mano el recibo de luz?', ayuda: 'Si no, no pasa nada: lo calculamos con tus electrodomésticos.', tipo: 'tarjetas', opciones: [['si', '🧾', 'Sí, lo tengo'], ['no', '🤷', 'No lo tengo']] },
    { id: 'kwh', seccion: 'Energía', titulo: '¿Cuántos kWh dice el recibo?', ayuda: 'Búscalo como "Consumo" o "kWh consumidos" del mes.', tipo: 'numero', min: 0, max: 3000, unidad: 'kWh', si: (r) => r.recibo === 'si' },
    { id: 'aparatos', seccion: 'Energía', titulo: '¿Cuáles de estos hay en tu casa?', ayuda: 'Toca todos los que tengan. Puedes elegir varios.', tipo: 'multi', opciones: APARATOS.map((a) => [a.codigo, a.emoji, a.nombre, a.nota ?? '']), si: (r) => r.recibo === 'no' },
    { id: 'horas', seccion: 'Energía', titulo: '¿Cuánto tiempo los usan?', ayuda: 'Un promedio está bien. La nevera ya la contamos encendida todo el día.', tipo: 'horas', si: (r) => r.recibo === 'no' && (r.aparatos ?? []).some((c) => c !== 'AP_NEVERA'),
      dato: `Una hora de aire acondicionado gasta lo mismo que unas ${ratioAire} horas de ventilador.` },
    { id: 'cocina', seccion: 'Cocina', titulo: '¿Con qué cocinan en tu casa?', ayuda: 'Elige el que más usan.', tipo: 'tarjetas', opciones: COMBUSTIBLES },
    { id: 'reciboGas', seccion: 'Cocina', titulo: '¿Tienes a mano el recibo del gas?', ayuda: 'Si no, lo estimamos con las comidas que preparan.', tipo: 'tarjetas', opciones: [['si', '🧾', 'Sí, lo tengo'], ['no', '🤷', 'No lo tengo']], si: (r) => r.cocina === 'gas_natural' },
    { id: 'm3', seccion: 'Cocina', titulo: '¿Cuántos m³ dice el recibo del gas?', ayuda: 'Aparece como "Consumo m³" del mes.', tipo: 'numero', min: 0, max: 200, unidad: 'm³', si: (r) => r.cocina === 'gas_natural' && r.reciboGas === 'si' },
    { id: 'comidas', seccion: 'Cocina', titulo: '¿Qué comidas se cocinan en casa casi todos los días?', ayuda: 'Toca todas las que apliquen.', tipo: 'multi', opciones: COMIDAS, si: (r) => ['glp', 'electrica'].includes(r.cocina) || (r.cocina === 'gas_natural' && r.reciboGas === 'no'),
      dato: 'En la costa Caribe, cocinar el almuerzo gasta más gas que el desayuno y la cena juntos (UPME).' },
    { id: 'medio', seccion: 'Movilidad', titulo: '¿Cómo llegas normalmente a la universidad?', ayuda: 'El medio en el que haces la mayor parte del camino.', tipo: 'tarjetas', opciones: MEDIOS.map((m) => [...m, '']) },
    { id: 'distancia', seccion: 'Movilidad', titulo: '¿A qué distancia vives de la universidad?', ayuda: 'Solo de ida. Un cálculo aproximado está bien.', tipo: 'chips', opciones: DISTANCIAS },
    { id: 'dias', seccion: 'Movilidad', titulo: '¿Cuántos días a la semana vas?', ayuda: '', tipo: 'chips', opciones: [1, 2, 3, 4, 5, 6, 7].map((d) => [String(d), String(d)]) },
    { id: 'ocupantes', seccion: 'Movilidad', titulo: '¿Cuántas personas van en el carro, contándote?', ayuda: 'Compartir el carro reparte la huella.', tipo: 'contador', min: 1, max: 5, si: (r) => r.medio === 'carro_gasolina',
      dato: `Si compartes el carro con 2 compañeros, cada uno emite ${carro3} % menos que yendo en bus.` },
    { id: 'vuela', seccion: 'Vuelos', titulo: '¿Viajaste en avión este mes?', ayuda: '', tipo: 'tarjetas', opciones: [['si', '✈️', 'Sí'], ['no', '🏠', 'No']] },
    { id: 'vuelos', seccion: 'Vuelos', titulo: '¿Cuántos vuelos tomaste?', ayuda: 'Cada despegue cuenta: ida y regreso son 2 vuelos.', tipo: 'vuelos', si: (r) => r.vuela === 'si',
      dato: 'Un vuelo Santa Marta–Bogotá emite unos 160 kg de CO₂e: más que 5 meses yendo en bus a la universidad.' },
  ];
}

function completo(p, r) {
  const v = r[p.id];
  if (p.tipo === 'multi') return p.id === 'aparatos' ? true : (v ?? []).length > 0;
  if (p.tipo === 'horas') return (r.aparatos ?? []).filter((c) => c !== 'AP_NEVERA').every((c) => r.horas?.[c] != null);
  if (p.tipo === 'vuelos') return Object.values(r.vuelos ?? {}).some((x) => x > 0);
  if (p.tipo === 'numero') return v != null && v !== '' && Number(v) >= p.min && Number(v) <= p.max;
  return v != null && v !== '';
}

// ---------- vista ----------
export async function vistaEncuesta({ sb, estado, app, irA, previa }) {
  const [{ data: fes }, { data: pes }] = await Promise.all([
    sb.from('emission_factors').select('activity, factor_value, version, valid_to, status').in('status', ['aprobado', 'provisional']).order('version'),
    sb.from('parametros_estimacion').select('*'),
  ]);
  const fe = {}; (fes ?? []).filter((f) => !f.valid_to).forEach((f) => { fe[f.activity] = Number(f.factor_value); });
  const pe = {}; (pes ?? []).forEach((p) => { pe[p.codigo] = { ...p, valor: Number(p.valor) }; });
  if (pe.CV_DIAS_MES) pe.CV_DIAS_MES = pe.CV_DIAS_MES.valor;
  if (pe.CV_SEMANAS_MES) pe.CV_SEMANAS_MES = pe.CV_SEMANAS_MES.valor;
  const r = respuestasDesde(previa);
  const todos = pasos(fe, pe);
  let i = 0;

  const visibles = () => todos.filter((p) => !p.si || p.si(r));
  const pintar = () => {
    const vis = visibles(); i = Math.min(i, vis.length - 1);
    const p = vis[i], est = estimar(r, fe, pe), pct = Math.round((i / vis.length) * 100);
    app.innerHTML = `
      <div class="wiz">
        <div class="wiz-top">
          <span class="wiz-sec">${h(p.seccion)} · ${i + 1} de ${vis.length}</span>
          <span class="wiz-live" aria-live="polite">👣 Tu huella va en <b>${n1(est.total)} kg CO₂e</b></span>
        </div>
        <div class="wiz-barra" role="progressbar" aria-valuenow="${pct}" aria-valuemin="0" aria-valuemax="100"><div style="width:${pct}%"></div></div>
        <h1 class="wiz-q">${h(p.titulo)}</h1>
        ${p.ayuda ? `<p class="ayuda">${h(p.ayuda)}</p>` : ''}
        <div class="wiz-body">${cuerpo(p)}</div>
        ${p.dato && completo(p, r) ? `<div class="dato" role="note"><b>¿Sabías que…?</b> ${h(p.dato)}</div>` : ''}
        <p id="msg" role="alert"></p>
        <div class="wiz-nav">
          <button class="boton secundario" id="atras" type="button" ${i === 0 ? 'disabled' : ''}>← Atrás</button>
          <button class="boton" id="sig" type="button" ${completo(p, r) ? '' : 'disabled'}>${i === vis.length - 1 ? 'Ver mi huella 🌱' : 'Siguiente →'}</button>
        </div>
      </div>`;
    enlazar(p);
  };

  const cuerpo = (p) => {
    const v = r[p.id];
    if (p.tipo === 'tarjetas') return `<div class="tiles">${p.opciones.map(([val, emo, t, sub]) =>
      `<button type="button" class="tile ${v === val ? 'sel' : ''}" data-v="${val}" aria-pressed="${v === val}"><span class="emo">${emo}</span><span>${h(t)}</span>${sub ? `<small>${h(sub)}</small>` : ''}</button>`).join('')}</div>`;
    if (p.tipo === 'multi') return `<div class="tiles">${p.opciones.map(([val, emo, t, sub]) => {
      const on = (v ?? []).includes(val);
      return `<button type="button" class="tile ${on ? 'sel' : ''}" data-m="${val}" aria-pressed="${on}"><span class="emo">${emo}</span><span>${h(t)}</span>${sub ? `<small>${h(sub)}</small>` : ''}</button>`; }).join('')}</div>`;
    if (p.tipo === 'chips') return `<div class="chips">${p.opciones.map(([val, t]) =>
      `<button type="button" class="chip ${String(v) === val ? 'sel' : ''}" data-v="${val}" aria-pressed="${String(v) === val}">${h(t)}</button>`).join('')}</div>`;
    if (p.tipo === 'contador') return `<div class="contador"><button type="button" class="redondo" data-d="-1" aria-label="Menos">−</button><span class="cifra">${v ?? p.min}</span><button type="button" class="redondo" data-d="1" aria-label="Más">+</button></div>`;
    if (p.tipo === 'numero') return `<div class="num"><input id="numv" type="number" inputmode="decimal" min="${p.min}" max="${p.max}" value="${h(v ?? '')}" aria-label="${h(p.titulo)}"><span>${h(p.unidad)}</span></div>`;
    if (p.tipo === 'horas') return (r.aparatos ?? []).filter((c) => c !== 'AP_NEVERA').map((c) => {
      const a = APARATOS.find((x) => x.codigo === c), sem = pe[c]?.modo === 'semana', ops = sem ? HORAS_SEMANA : HORAS_DIA, sel = r.horas?.[c];
      return `<div class="fila-horas"><p><span class="emo">${a.emoji}</span> <b>${h(a.nombre)}</b> <small>${sem ? 'horas a la semana' : 'horas al día'}</small></p>
        <div class="chips">${ops.map(([val, t]) => `<button type="button" class="chip ${String(sel) === val ? 'sel' : ''}" data-ap="${c}" data-v="${val}" aria-pressed="${String(sel) === val}">${t}</button>`).join('')}</div></div>`; }).join('');
    if (p.tipo === 'vuelos') return VUELOS.map(([c, emo, t, sub]) => `<div class="fila-horas"><p><span class="emo">${emo}</span> <b>${t}</b> <small>${sub}</small></p>
      <div class="contador"><button type="button" class="redondo" data-vu="${c}" data-d="-1" aria-label="Menos vuelos ${t}">−</button><span class="cifra">${r.vuelos?.[c] ?? 0}</span><button type="button" class="redondo" data-vu="${c}" data-d="1" aria-label="Más vuelos ${t}">+</button></div></div>`).join('');
    return '';
  };

  const enlazar = (p) => {
    app.querySelectorAll('[data-v]').forEach((b) => b.addEventListener('click', () => {
      if (b.dataset.ap) { r.horas = { ...(r.horas ?? {}), [b.dataset.ap]: Number(b.dataset.v) }; }
      else { r[p.id] = p.tipo === 'chips' ? Number(b.dataset.v) : b.dataset.v; pintar(); return avanzar(); }
      pintar();
    }));
    app.querySelectorAll('[data-m]').forEach((b) => b.addEventListener('click', () => {
      const s = new Set(r[p.id] ?? []); s.has(b.dataset.m) ? s.delete(b.dataset.m) : s.add(b.dataset.m); r[p.id] = [...s]; pintar();
    }));
    app.querySelectorAll('[data-d]').forEach((b) => b.addEventListener('click', () => {
      const d = Number(b.dataset.d);
      if (b.dataset.vu) { const c = b.dataset.vu; r.vuelos = { ...(r.vuelos ?? {}), [c]: Math.max(0, Math.min(20, (r.vuelos?.[c] ?? 0) + d)) }; }
      else r[p.id] = Math.max(p.min, Math.min(p.max, (r[p.id] ?? p.min) + d));
      pintar();
    }));
    const inp = document.getElementById('numv');
    if (inp) { inp.focus(); inp.addEventListener('input', () => {
      r[p.id] = inp.value === '' ? null : Number(inp.value);
      const ok = completo(p, r); document.getElementById('sig').disabled = !ok;
      document.getElementById('msg').textContent = inp.value !== '' && !ok ? `Escribe un valor entre ${p.min} y ${p.max.toLocaleString('es-CO')} ${p.unidad}.` : '';
      document.querySelector('.wiz-live b').textContent = `${n1(estimar(r, fe, pe).total)} kg CO₂e`;
    }); }
    document.getElementById('atras').addEventListener('click', () => { i = Math.max(0, i - 1); pintar(); });
    document.getElementById('sig').addEventListener('click', () => (i === visibles().length - 1 ? enviar() : avanzar()));
  };
  const avanzar = () => { setTimeout(() => { if (i < visibles().length - 1) { i++; pintar(); } }, 180); };
  if (r.personas == null) r.personas = 1;

  const enviar = async () => {
    const btn = document.getElementById('sig'); btn.disabled = true; btn.textContent = 'Calculando…';
    try {
      let id = previa?.id;
      const datos = { personas_hogar: r.personas, status: 'enviada', submitted_at: new Date().toISOString(), updated_at: new Date().toISOString() };
      if (!id) {
        const { data, error } = await sb.from('surveys').insert({ profile_id: estado.user.id, period_id: estado.periodo.id, consent_id: estado.consent.id, ...datos }).select().single();
        if (error) throw error; id = data.id;
      } else {
        const u = await sb.from('surveys').update(datos).eq('id', id); if (u.error) throw u.error;
        const d = await sb.from('activity_answers').delete().eq('survey_id', id); if (d.error) throw d.error;
      }
      const filas = filasDesde(r).map((f) => ({ ...f, survey_id: id }));
      const ins = await sb.from('activity_answers').insert(filas); if (ins.error) throw ins.error;
      const c = await sb.rpc('calcular_encuesta', { p_survey: id }); if (c.error) throw c.error;
      irA('#informe');
    } catch (e) { document.getElementById('msg').textContent = e.message ?? String(e); btn.disabled = false; btn.textContent = 'Ver mi huella 🌱'; }
  };
  pintar();
}

function filasDesde(r) {
  const f = (category, question_code, numeric_value = null, text_value = null) => ({ category, question_code, numeric_value, text_value });
  const out = [f('electricidad', 'E00', null, r.recibo)];
  if (r.recibo === 'si') out.push(f('electricidad', 'E01', r.kwh));
  else for (const c of r.aparatos ?? []) out.push(f('electricidad', c, c === 'AP_NEVERA' ? 24 : r.horas?.[c] ?? 0));
  out.push(f('gas', 'C01', null, r.cocina));
  if (r.cocina === 'gas_natural') out.push(f('gas', 'C00', null, r.reciboGas));
  if (r.cocina === 'gas_natural' && r.reciboGas === 'si') out.push(f('gas', 'C02', r.m3));
  else if (['gas_natural', 'glp', 'electrica'].includes(r.cocina)) for (const c of r.comidas ?? []) out.push(f('gas', c, 1));
  out.push(f('movilidad', 'T01', null, r.medio), f('movilidad', 'T02', r.distancia), f('movilidad', 'T03', r.dias));
  if (r.medio === 'carro_gasolina') out.push(f('movilidad', 'T04', r.ocupantes ?? 1));
  out.push(f('vuelos', 'V00', null, r.vuela));
  if (r.vuela === 'si') for (const [c] of VUELOS) if (r.vuelos?.[c]) out.push(f('vuelos', c, r.vuelos[c]));
  return out;
}

function respuestasDesde(previa) {
  const r = { personas: previa?.personas_hogar ?? null, aparatos: [], horas: {}, comidas: [], vuelos: {} };
  for (const a of previa?.activity_answers ?? []) {
    const n = a.numeric_value == null ? null : Number(a.numeric_value), t = a.text_value;
    if (a.question_code === 'E00') r.recibo = t; else if (a.question_code === 'E01') r.kwh = n;
    else if (a.question_code.startsWith('AP_')) { r.aparatos.push(a.question_code); if (a.question_code !== 'AP_NEVERA') r.horas[a.question_code] = n; }
    else if (a.question_code === 'C01') r.cocina = t; else if (a.question_code === 'C00') r.reciboGas = t; else if (a.question_code === 'C02') r.m3 = n;
    else if (a.question_code.startsWith('CO_')) r.comidas.push(a.question_code);
    else if (a.question_code === 'T01') r.medio = t; else if (a.question_code === 'T02') r.distancia = n;
    else if (a.question_code === 'T03') r.dias = n; else if (a.question_code === 'T04') r.ocupantes = n;
    else if (a.question_code === 'V00') r.vuela = t; else if (a.question_code.startsWith('VU_')) r.vuelos[a.question_code] = n;
  }
  return r;
}

// ---------- informe ----------
const NOMBRE = Object.fromEntries([...APARATOS.map((a) => [a.codigo, `${a.emoji} ${a.nombre}`]),
  ['E01', '🧾 Recibo de luz'], ['C01', '🍳 Cocina'], ['T02', '🚌 Ida y vuelta a la U'], ['VU_NACIONAL', '🇨🇴 Vuelos nacionales'], ['VU_CORTO', '🌴 Vuelos cercanos'], ['VU_LARGO', '🌍 Vuelos lejanos']]);
const CAT = { electricidad: ['⚡', 'Energía en casa'], gas: ['🍳', 'Cocina'], movilidad: ['🚌', 'Movilidad'], vuelos: ['✈️', 'Vuelos'] };

export async function vistaInforme({ sb, app }) {
  const { data: calc } = await sb.from('calculations')
    .select('*, surveys!inner(personas_hogar, survey_periods(name), activity_answers(question_code, numeric_value, text_value)), calculation_details(*, emission_factors(activity, factor_value, unit_activity, source, source_url, reference_year, geography, status), activity_answers(question_code, is_estimated))')
    .order('calculated_at', { ascending: false }).limit(1).maybeSingle();
  if (!calc) { app.innerHTML = '<h1>Mi huella</h1><p class="tarjeta">Aún no tienes un resultado. <a href="#encuesta">Responde la encuesta</a>: toma 3 minutos.</p>'; return; }
  const det = calc.calculation_details;
  const porCat = {}; det.forEach((d) => { porCat[d.category] = (porCat[d.category] ?? 0) + Number(d.emissions_kgco2e); });
  const cats = Object.entries(porCat).sort((a, b) => b[1] - a[1]);
  const total = Number(calc.total_kgco2e), max = Math.max(...cats.map((c) => c[1]), 1);
  const items = det.filter((d) => Number(d.emissions_kgco2e) > 0).map((d) => ({ n: NOMBRE[d.activity_answers?.question_code] ?? d.category, kg: Number(d.emissions_kgco2e), est: d.activity_answers?.is_estimated }))
    .sort((a, b) => b.kg - a.kg);
  const resp = Object.fromEntries((calc.surveys?.activity_answers ?? []).map((a) => [a.question_code, a.numeric_value ?? a.text_value]));
  const personas = Math.max(Number(calc.surveys?.personas_hogar) || 1, 1);
  const fac = Object.fromEntries(det.map((d) => [d.emission_factors?.activity, Number(d.emission_factors?.factor_value)]));
  const kmCarro = total / 0.16152;
  const reto = elegirReto(cats[0]?.[0], resp, personas, fac);
  const estimado = det.some((d) => d.activity_answers?.is_estimated);

  app.innerHTML = `
    <div class="resultado">
      <p class="ayuda">${h(calc.surveys?.survey_periods?.name)} · tu huella del mes</p>
      <p class="total">${n1(total)} <span>kg CO₂e</span></p>
      <p>Es lo que emite un carro a gasolina recorriendo unos <b>${Math.round(kmCarro).toLocaleString('es-CO')} km</b>.</p>
      ${estimado ? '<p class="etiqueta">Incluye estimaciones con valores típicos (no tenías el recibo)</p>' : ''}
    </div>
    <div class="tarjeta"><h2>¿De dónde sale?</h2><div class="barras">
      ${cats.map(([c, v]) => `<div class="barra-cat"><span>${CAT[c][0]} ${CAT[c][1]}</span><div class="relleno" style="width:${(v / max) * 100}%"></div><span>${n1(v)} kg</span></div>`).join('')}</div>
      ${cats[0] ? `<p>Tu mayor fuente es <b>${CAT[cats[0][0]][1].toLowerCase()}</b>.</p>` : ''}</div>
    ${reto ? `<div class="reto"><h2>🏆 Tu reto del mes</h2><p>${reto}</p></div>` : ''}
    <div class="tarjeta"><h2>El detalle</h2><table><thead><tr><th>Qué</th><th>kg CO₂e</th></tr></thead><tbody>
      ${items.map((x) => `<tr><td>${h(x.n)} ${x.est ? '<span class="etiqueta">estimado</span>' : ''}</td><td>${x.kg < 0.05 ? '&lt; 0,1' : n1(x.kg)}</td></tr>`).join('')}</tbody></table></div>
    <details class="tarjeta"><summary><b>¿Cómo lo calculamos?</b></summary>
      <p>Cada actividad se multiplica por un factor de emisión con fuente. Método ${h(calc.methodology_version)}, calculado el ${new Date(calc.calculated_at).toLocaleString('es-CO')}</p>
      <ul>${[...new Map(det.map((d) => [d.emission_factors?.source, d.emission_factors])).values()].map((f) => `<li>${Number(f.factor_value).toLocaleString('es-CO', { maximumFractionDigits: 5 })} kg CO₂e/${h(f.unit_activity)} · <a href="${h(f.source_url)}" target="_blank" rel="noopener">${h(f.source)}</a> (${f.reference_year}, ${h(f.geography)})</li>`).join('')}</ul>
      <p class="ayuda">Es una estimación educativa: usa rangos y valores típicos, factores de transporte del Reino Unido y no incluye alimentación ni compras.</p></details>
    <a class="boton secundario" href="#encuesta">Cambiar mis respuestas</a>`;
}

function elegirReto(cat, r, personas, fac) {
  const fe = fac.electricidad_sin ?? 0.22;
  if (cat === 'electricidad' && r.AP_AIRE) {
    const kg = (1.013 * 1 * 30.4 / personas) * fe;
    return `Usa el aire acondicionado <b>1 hora menos al día</b> (o ponlo en 24 °C). Te ahorras unos <b>${n1(kg)} kg CO₂e</b> al mes.`;
  }
  if (cat === 'electricidad') return 'Desconecta cargadores y aparatos que no uses, y apaga los bombillos al salir de cada cuarto. Pequeños cambios suman cada mes.';
  if (cat === 'movilidad' && r.T01 === 'carro_gasolina') return 'Comparte el carro con un compañero que viva cerca: tu huella de movilidad <b>baja a la mitad</b>.';
  if (cat === 'movilidad' && ['moto', 'mototaxi', 'taxi'].includes(r.T01)) return 'Si vives a menos de 3 km, prueba ir a pie o en bicicleta 1 día a la semana: son kilómetros con cero emisiones.';
  if (cat === 'movilidad') return 'Vas muy bien: el bus es de las formas de llegar que menos emite por persona. Invita a alguien a probarlo.';
  if (cat === 'gas') return 'Tapa las ollas y apaga la llama un par de minutos antes: el calor termina la cocción y gastas menos gas.';
  if (cat === 'vuelos') return 'Los vuelos pesan mucho: cuando sea posible, prefiere vuelos directos y combina varios planes en un mismo viaje.';
  return '';
}
