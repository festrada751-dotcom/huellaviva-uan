-- HuellaViva UAN · Datos SINTÉTICOS de prueba. No contiene personas reales.

-- Aviso de consentimiento (borrador para revisión institucional)
insert into public.consent_versions (id, version, texto, purpose, valid_from, active) values
('00000000-0000-0000-0000-0000000000c1', 'v1.0-2026-11',
 'La Universidad Antonio Nariño, como responsable que deberá identificarse y validar este aviso institucionalmente, solicita sus respuestas para estimar su huella de carbono y generar informes individuales y estadísticas agregadas de la comunidad universitaria. La participación es voluntaria. Las respuestas se tratarán para la finalidad informada y se protegerán con controles de acceso. Puede consultar, actualizar o solicitar la atención de sus derechos por el canal institucional indicado. Consulte el aviso completo de privacidad antes de continuar.',
 'Estimar huella de carbono individual y estadísticas agregadas', '2026-11-01', true);

-- Periodo
insert into public.survey_periods (id, name, start_date, end_date, methodology_version, status) values
('00000000-0000-0000-0000-0000000000a1', 'Octubre 2026', '2026-10-01', '2026-10-31', 'HV-1.1', 'abierto');

-- Tarifas Air-e octubre 2026, nivel 1, propiedad operador de red ($/kWh), tomadas de https://www.air-e.com/tarifas (consultado 21/11/2026)
insert into public.tariffs (period_id, operador, estrato, cop_kwh, source) values
('00000000-0000-0000-0000-0000000000a1', 'Air-e', 1,  555.25, 'Air-e, tarifas octubre 2026, estrato 1 (subsidiada)'),
('00000000-0000-0000-0000-0000000000a1', 'Air-e', 2,  694.06, 'Air-e, tarifas octubre 2026, estrato 2 (subsidiada)'),
('00000000-0000-0000-0000-0000000000a1', 'Air-e', 3,  795.94, 'Air-e, tarifas octubre 2026, estrato 3 (subsidiada)'),
('00000000-0000-0000-0000-0000000000a1', 'Air-e', 4,  936.40, 'Air-e, tarifas octubre 2026, CU + COT (sin subsidio ni contribución)'),
('00000000-0000-0000-0000-0000000000a1', 'Air-e', 5, 1123.67, 'Air-e, tarifas octubre 2026, CU + COT + contribución'),
('00000000-0000-0000-0000-0000000000a1', 'Air-e', 6, 1123.67, 'Air-e, tarifas octubre 2026, CU + COT + contribución'),
('00000000-0000-0000-0000-0000000000a1', 'Air-e', null, 936.40, 'Air-e, tarifas octubre 2026, CU + COT; se usa si no se indica estrato');

-- Factores v1 (ver sección 5 del documento; verificar antes de un piloto)
insert into public.emission_factors
 (code, version, category, activity, factor_value, unit_activity, geography, source, source_url, reference_year, method, valid_from, status) values
('FE-ELE-01',1,'electricidad','electricidad_sin',0.220,'kWh','Colombia','UPME Resolución 000085 de 2026','https://gestornormativo.creg.gov.co/gestor/entorno/docs/resolucion_upme_0085_2026.htm',2024,'Factor para inventarios de GEI','2026-01-01','aprobado'),
('FE-GLP-01',1,'gas','glp',3.0513,'kg','Colombia','UPME FECOC - GLP Cartagena: CO2 3,0488 kg/kg + CH4 1 kg/TJ (x28) + N2O 0,1 kg/TJ (x265) con LHV 45,4134 MJ/kg','https://app.upme.gov.co/Calculadora_Emisiones1/new/calculadora.html',2016,'Consultado 21/11/2026; aplicación estacionaria','2026-01-01','aprobado'),
('FE-GN-01',1,'gas','gas_natural',1.8410,'m3','Colombia','UPME FECOC - Gas Natural Guajira: CO2 1,8392 kg/m3 + CH4 0,0335 g/m3 (x28) + N2O 0,1 kg/TJ x PCI 33,4943 MJ/m3 (x265)','https://app.upme.gov.co/Calculadora_Emisiones1/new/calculadora.html',2016,'Consultado 21/11/2026; aplicación estacionaria','2026-01-01','aprobado'),
('FE-CAR-01',1,'movilidad','carro_gasolina',0.16152,'km','Reino Unido','DESNZ/DEFRA Conversion Factors 2026','https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2026',2026,'Average petrol car','2026-01-01','aprobado'),
('FE-TAX-01',1,'movilidad','taxi',0.16152,'km','Reino Unido','DESNZ/DEFRA Conversion Factors 2026 (carro gasolina)','https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2026',2026,'Supuesto: taxi = carro gasolina','2026-01-01','aprobado'),
('FE-BUS-01',1,'movilidad','bus',0.1305,'pkm','Reino Unido','DESNZ/DEFRA Conversion Factors 2025 (local bus)','https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2025',2025,'0,21 kg/pasajero-milla / 1,609','2026-01-01','aprobado'),
('FE-MOT-01',1,'movilidad','moto',0.11367,'km','Reino Unido','DEFRA 2023 (average motorbike)','https://www.dur.ac.uk/media/durham-university/professional-services/energy-and-sustainability-team/CO2-conversion-factors-2023-24.pdf',2023,'Provisional: actualizar a 2026','2026-01-01','provisional'),
('FE-MTX-01',1,'movilidad','mototaxi',0.11367,'km','Reino Unido','DEFRA 2023 (average motorbike)','https://www.dur.ac.uk/media/durham-university/professional-services/energy-and-sustainability-team/CO2-conversion-factors-2023-24.pdf',2023,'Supuesto: mototaxi = moto','2026-01-01','provisional'),
('FE-PIE-01',1,'movilidad','pie',0,'km','—','Supuesto sin combustión','https://ghgprotocol.org/corporate-standard',2026,'Cero emisiones directas','2026-01-01','aprobado'),
('FE-BIC-01',1,'movilidad','bicicleta',0,'km','—','Supuesto sin combustión','https://ghgprotocol.org/corporate-standard',2026,'Cero emisiones directas','2026-01-01','aprobado'),
('FE-VNA-01',1,'vuelos','vuelo_nacional',0.22928,'pkm','Reino Unido','DESNZ/DEFRA Conversion Factors 2026 (domestic, con RF)','https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2026',2026,'700 km por trayecto (supuesto)','2026-01-01','aprobado'),
('FE-VIC-01',1,'vuelos','vuelo_corto',0.12576,'pkm','Reino Unido','DESNZ/DEFRA Conversion Factors 2026 (short-haul economy, con RF)','https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2026',2026,'2.000 km por trayecto (supuesto)','2026-01-01','aprobado'),
('FE-VIL-01',1,'vuelos','vuelo_largo',0.11704,'pkm','Reino Unido','DESNZ/DEFRA Conversion Factors 2026 (long-haul economy, con RF)','https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2026',2026,'8.500 km por trayecto (supuesto)','2026-01-01','aprobado');

-- Los usuarios y respuestas sintéticas se crean en tests/rls_y_calculo.sql (dentro de una transacción que se revierte).
