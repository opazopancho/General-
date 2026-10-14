-- =============================================================================
-- DATOS SINTÉTICOS DE EJEMPLO · PÓRTICO DIMENSIONAL PREDICTIVO DE NEUMÁTICOS CAEX
-- Equipo 3 · USACH
--
-- Todo es inventado: no hay datos de una faena ni de personas reales.
-- Reproduce la flota de las pantallas del prototipo (CAEX-101 a CAEX-106, pórtico
-- P-100, cámaras CAM-101 a CAM-108) y los casos del caso de uso:
--   · ocho pasadas por camión, cada 100 h de operación (≈ 5 días)
--   · neumáticos en zona roja, amarilla, verde y uno sin datos (CAEX-104 P2)
--   · extensión 3a: serial no identificado (CAEX-105 P6, última pasada)
--   · extensión 4a: medición fuera de tolerancia por barro (CAEX-101 P4, última pasada)
--   · extensión 5a: daño crítico y alerta atendida por el despachador (CAEX-102 P3)
--   · corrección humana de un daño (CAEX-106 P4)
--   · órdenes programada, reprogramada, ejecutada y anulada, con su bitácora
--   · un neumático retirado por falla imprevista (para los indicadores)
--
-- Se ejecuta UNA vez, sobre la base vacía, después de la migración.
-- Con la CLI de Supabase se carga solo al hacer `supabase db reset`.
-- =============================================================================
BEGIN;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM camiones) THEN
        RAISE EXCEPTION 'La base ya tiene datos: este archivo se ejecuta sobre una base vacía.';
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- Usuarios ficticios (los uuid son fijos para poder referenciarlos)
-- -----------------------------------------------------------------------------
INSERT INTO usuarios (id_usuario, nombre, correo, rol, creado_por, creado_en) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Sistema pórtico y modelo', 'sistema@example.com',      'sistema',          NULL,                                   '2026-08-01 09:00-04'),
  ('00000000-0000-0000-0000-000000000002', 'Administración demo',      'admin@example.com',        'administrador',    '00000000-0000-0000-0000-000000000001', '2026-08-01 09:05-04'),
  ('00000000-0000-0000-0000-000000000003', 'Planificador demo',        'planificador@example.com', 'planificador',     '00000000-0000-0000-0000-000000000002', '2026-08-01 09:10-04'),
  ('00000000-0000-0000-0000-000000000004', 'Despachador demo',         'despacho@example.com',     'despachador',      '00000000-0000-0000-0000-000000000002', '2026-08-01 09:10-04'),
  ('00000000-0000-0000-0000-000000000005', 'Operador pórtico demo',    'portico@example.com',      'operador_portico', '00000000-0000-0000-0000-000000000002', '2026-08-01 09:10-04'),
  ('00000000-0000-0000-0000-000000000006', 'Taller neumáticos demo',   'taller@example.com',       'taller',           '00000000-0000-0000-0000-000000000002', '2026-08-01 09:10-04');

-- -----------------------------------------------------------------------------
-- Configuración y catálogos
-- -----------------------------------------------------------------------------
INSERT INTO versiones_modelo (modelo_version, descripcion, umbral_rojo_h, umbral_amarillo_h, confianza_minima, mediciones_minimas, vigente, creado_por, creado_en)
VALUES ('v1.3', 'Regresión lineal de profundidad contra horas de operación por serial; tasa nominal del tipo de neumático con menos de dos mediciones.',
        200, 500, 0.70, 2, true, '00000000-0000-0000-0000-000000000002', '2026-08-01 10:00-04');

-- La profundidad nueva es referencial: confirmar con la ficha del fabricante.
-- Se usa una sola medida para simplificar; en faena cada modelo de CAEX tiene la suya.
INSERT INTO tipos_neumatico (marca, medida, profundidad_nueva_mm, umbral_retiro_mm, tasa_nominal_mm_100h, creado_por, creado_en) VALUES
  ('Bridgestone', '59/80R63', 97.0, 20.0, 1.10, '00000000-0000-0000-0000-000000000002', '2026-08-01 10:05-04'),
  ('Michelin',    '59/80R63', 97.0, 20.0, 1.10, '00000000-0000-0000-0000-000000000002', '2026-08-01 10:05-04'),
  ('BKT',         '59/80R63', 97.0, 20.0, 1.10, '00000000-0000-0000-0000-000000000002', '2026-08-01 10:05-04');

INSERT INTO camiones (codigo_camion, modelo_camion, creado_por, creado_en) VALUES
  ('CAEX-101', 'Cat 793F',       '00000000-0000-0000-0000-000000000002', '2026-08-01 10:10-04'),
  ('CAEX-102', 'Cat 793F',       '00000000-0000-0000-0000-000000000002', '2026-08-01 10:10-04'),
  ('CAEX-103', 'Komatsu 930E-4', '00000000-0000-0000-0000-000000000002', '2026-08-01 10:10-04'),
  ('CAEX-104', 'Cat 797F',       '00000000-0000-0000-0000-000000000002', '2026-08-01 10:10-04'),
  ('CAEX-105', 'Komatsu 930E-4', '00000000-0000-0000-0000-000000000002', '2026-08-01 10:10-04'),
  ('CAEX-106', 'Cat 793F',       '00000000-0000-0000-0000-000000000002', '2026-08-01 10:10-04');

INSERT INTO porticos (codigo_portico, ubicacion, estado_portico, calibrado_en, creado_por, creado_en)
VALUES ('P-100', 'Salida del taller de camiones (punto obligatorio de tránsito)', 'simulado', '2026-08-15 09:00-04',
        '00000000-0000-0000-0000-000000000005', '2026-08-01 10:15-04');

INSERT INTO sensores (id_portico, codigo_sensor, tipo_sensor, ubicacion_sensor, cobertura, creado_por, creado_en)
SELECT p.id_portico, s.codigo, s.tipo, s.ubicacion, s.cobertura, '00000000-0000-0000-0000-000000000005', '2026-08-01 10:20-04'
FROM porticos p
CROSS JOIN (VALUES
  ('CAM-101',  'camara',        'Frontal centro',            'Dirección frontal y banda delantera'),
  ('CAM-102',  'camara',        'Frontal derecha (lateral)', 'P2 delantero derecho (flanco externo)'),
  ('CAM-103',  'camara',        'Lateral derecha (centro)',  'P4 y P6 tándem derecho (banda)'),
  ('CAM-104',  'camara',        'Trasera derecha (lateral)', 'P6 trasero externo derecho (flanco)'),
  ('CAM-105',  'camara',        'Trasera centro',            'P3, P4, P5 y P6 banda trasera dual'),
  ('CAM-106',  'camara',        'Trasera izquierda (lateral)','P3 trasero externo izquierdo (flanco)'),
  ('CAM-107',  'camara',        'Lateral izquierda (centro)','P3 y P5 tándem izquierdo (banda)'),
  ('CAM-108',  'camara',        'Frontal izquierda (lateral)','P1 delantero izquierdo (flanco externo)'),
  ('ESC-101',  'escaner_3d',    'Arco superior',             'Banda de rodadura de las seis posiciones'),
  ('TER-101',  'termografia',   'Columnas laterales',        'Flancos de las seis posiciones'),
  ('RFID-101', 'rfid',          'Arco de entrada',           'Etiquetas RFID de los neumáticos que las tienen')
) AS s(codigo, tipo, ubicacion, cobertura)
WHERE p.codigo_portico = 'P-100';

-- -----------------------------------------------------------------------------
-- Perfil sintético de cada neumático
--   horas_rem_ultima: horas remanentes que debe mostrar en la última pasada
--   tasa: desgaste en mm cada 100 h
-- Los nueve primeros son los neumáticos de las pantallas del prototipo.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE _perfil (
    serial            text PRIMARY KEY,
    codigo_camion     text,
    posicion          smallint,
    marca             text,
    horas_rem_ultima  integer,      -- NULL = recién montado, sin mediciones
    tasa              numeric(4,2),
    desmontado_en     timestamptz,  -- solo el neumático retirado
    motivo_desmontaje text
) ON COMMIT DROP;

INSERT INTO _perfil (serial, codigo_camion, posicion, marca, horas_rem_ultima, tasa) VALUES
  ('5980R63-2426-1348', 'CAEX-102', 3, 'Bridgestone',   34, 1.17),
  ('5980R63-2328-1590', 'CAEX-106', 2, 'Bridgestone',   95, 1.79),
  ('5980R63-2345-1534', 'CAEX-105', 5, 'Michelin',     106, 1.14),
  ('5980R63-2618-1611', 'CAEX-106', 5, 'Bridgestone',  143, 1.61),
  ('5980R63-2531-1596', 'CAEX-106', 4, 'Bridgestone',  150, 1.94),
  ('5980R63-2312-1561', 'CAEX-105', 2, 'Michelin',     168, 2.44),
  ('5980R63-2218-1478', 'CAEX-103', 5, 'BKT',          392, 1.10),
  ('5980R63-2100-1301', 'CAEX-101', 1, 'Bridgestone', 1687, 1.10),
  ('5980R63-2150-1355', 'CAEX-104', 6, 'Michelin',    4020, 1.10);

-- Neumático que falló por un corte de impacto estando en zona verde (falla imprevista).
INSERT INTO _perfil VALUES
  ('5980R63-1988-1203', 'CAEX-104', 2, 'BKT', 640, 1.05, '2026-09-28 14:00-03', 'falla_imprevista');

-- Su reemplazo, montado después de la última pasada: aparece «sin datos».
INSERT INTO _perfil (serial, codigo_camion, posicion, marca) VALUES
  ('5980R63-2742-1742', 'CAEX-104', 2, 'Michelin');

-- Resto de la flota, en zona verde.
INSERT INTO _perfil (serial, codigo_camion, posicion, marca, horas_rem_ultima, tasa)
SELECT format('5980R63-27%s%s-17%s%s', c, p, c, p),
       'CAEX-10' || c,
       p,
       (ARRAY['Bridgestone','Michelin','BKT'])[1 + (c + p) % 3],
       600 + ((c * 7 + p * 13) % 20) * 150,
       round(0.95 + ((c + p) % 5) * 0.08, 2)
FROM generate_series(1, 6) c, generate_series(1, 6) p
WHERE NOT EXISTS (SELECT 1 FROM _perfil f WHERE f.codigo_camion = 'CAEX-10' || c AND f.posicion = p);

-- -----------------------------------------------------------------------------
-- Neumáticos y montajes
-- -----------------------------------------------------------------------------
-- Horas acumuladas en la última pasada, suponiendo banda nueva de 97 mm.
CREATE TEMP TABLE _calc ON COMMIT DROP AS
SELECT f.*,
       round(20 + f.horas_rem_ultima * f.tasa / 100, 1)                                      AS prof_ultima,
       round((97 - (20 + f.horas_rem_ultima * f.tasa / 100)) / f.tasa * 100)::int            AS horas_op_ultima
FROM _perfil f;

INSERT INTO neumaticos (serial, id_tipo_neumatico, rfid, estado_neumatico, fecha_ingreso, creado_por, creado_en)
SELECT c.serial, t.id_tipo_neumatico,
       CASE WHEN c.marca = 'Michelin' THEN 'E200-' || replace(substr(c.serial, 9), '-', '') END,
       CASE WHEN c.desmontado_en IS NOT NULL THEN 'dado_de_baja' ELSE 'montado' END,
       (DATE '2026-09-28' - coalesce(c.horas_op_ultima, 0) / 20 - 10),
       '00000000-0000-0000-0000-000000000002', '2026-08-01 11:00-04'
FROM _calc c
JOIN tipos_neumatico t ON t.marca = c.marca AND t.medida = '59/80R63';

-- Neumático de bodega que se usará como reemplazo.
INSERT INTO neumaticos (serial, id_tipo_neumatico, estado_neumatico, fecha_ingreso, creado_por, creado_en)
SELECT '5980R63-B-544', id_tipo_neumatico, 'disponible', DATE '2026-09-10', '00000000-0000-0000-0000-000000000002', '2026-09-10 12:00-03'
FROM tipos_neumatico WHERE marca = 'Bridgestone';

-- Primero el montaje ya cerrado (para liberar la posición), luego los vigentes.
INSERT INTO montajes (id_neumatico, id_camion, posicion, montado_en, horas_neumatico_al_montar,
                      desmontado_en, horas_neumatico_al_desmontar, motivo_desmontaje, creado_por, creado_en)
SELECT n.id_neumatico, ca.id_camion, c.posicion,
       CASE WHEN c.horas_rem_ultima IS NULL THEN TIMESTAMPTZ '2026-09-28 18:00-03'
            ELSE TIMESTAMPTZ '2026-09-28 06:00-03' - make_interval(hours => c.horas_op_ultima * 24 / 20) END,
       0,
       c.desmontado_en,
       CASE WHEN c.desmontado_en IS NOT NULL THEN c.horas_op_ultima + 6 END,
       c.motivo_desmontaje,
       '00000000-0000-0000-0000-000000000006',
       CASE WHEN c.horas_rem_ultima IS NULL THEN TIMESTAMPTZ '2026-09-28 18:10-03'
            ELSE TIMESTAMPTZ '2026-09-28 06:00-03' - make_interval(hours => c.horas_op_ultima * 24 / 20) END
FROM _calc c
JOIN neumaticos n ON n.serial = c.serial
JOIN camiones ca  ON ca.codigo_camion = c.codigo_camion
ORDER BY (c.desmontado_en IS NULL), c.serial;

-- -----------------------------------------------------------------------------
-- Pasadas: ocho por camión, cada 5 días; la última el 28-09-2026 en la mañana
-- -----------------------------------------------------------------------------
INSERT INTO pasadas (id_portico, id_camion, fecha_pasada, velocidad_kmh, horometro_h, origen_dato, creado_por, creado_en)
SELECT p.id_portico, ca.id_camion,
       TIMESTAMPTZ '2026-09-28 07:00-03' + make_interval(mins => 12 * x.n) - make_interval(days => 5 * (7 - k)),
       2.5 + ((x.n + k) % 5) * 0.5,
       x.horometro - (7 - k) * 100,
       'sintetico',
       '00000000-0000-0000-0000-000000000001',
       TIMESTAMPTZ '2026-09-28 07:01-03' + make_interval(mins => 12 * x.n) - make_interval(days => 5 * (7 - k))
FROM (VALUES ('CAEX-101', 1, 16791), ('CAEX-102', 2, 13622), ('CAEX-103', 3, 21087),
             ('CAEX-104', 4, 18450), ('CAEX-105', 5, 14120), ('CAEX-106', 6, 19830)) AS x(codigo, n, horometro)
JOIN camiones ca ON ca.codigo_camion = x.codigo
CROSS JOIN porticos p
CROSS JOIN generate_series(0, 7) k
WHERE p.codigo_portico = 'P-100'
ORDER BY 3;

-- -----------------------------------------------------------------------------
-- Mediciones: el neumático montado en cada posición al momento de la pasada
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE _pasada_k ON COMMIT DROP AS
SELECT pa.*, ca.codigo_camion,
       (row_number() OVER (PARTITION BY pa.id_camion ORDER BY pa.fecha_pasada) - 1)::int AS k
FROM pasadas pa JOIN camiones ca ON ca.id_camion = pa.id_camion;

INSERT INTO mediciones (id_pasada, posicion, id_neumatico, estado_identificacion, metodo_identificacion,
                        profundidad_mm, temperatura_flanco_c, horas_operacion_neumatico,
                        foto_url, nube_puntos_url, termografia_url, creado_por, creado_en)
SELECT pk.id_pasada, mo.posicion, mo.id_neumatico, 'identificado',
       CASE WHEN c.marca = 'Michelin' THEN 'rfid' ELSE 'ocr_serial' END,
       round(20 + (c.horas_rem_ultima + (7 - pk.k) * 100) * c.tasa / 100, 1),
       68 + (mo.posicion * 3 + pk.k) % 9 + CASE WHEN c.serial = '5980R63-2426-1348' AND pk.k = 7 THEN 19 ELSE 0 END,
       c.horas_op_ultima - (7 - pk.k) * 100,
       format('evidencias/%s/%s/p%s-foto.jpg',  pk.codigo_camion, to_char(pk.fecha_pasada AT TIME ZONE 'America/Santiago', 'YYYYMMDD-HH24MI'), mo.posicion),
       format('evidencias/%s/%s/p%s-escaner.ply', pk.codigo_camion, to_char(pk.fecha_pasada AT TIME ZONE 'America/Santiago', 'YYYYMMDD-HH24MI'), mo.posicion),
       format('evidencias/%s/%s/p%s-termica.png', pk.codigo_camion, to_char(pk.fecha_pasada AT TIME ZONE 'America/Santiago', 'YYYYMMDD-HH24MI'), mo.posicion),
       '00000000-0000-0000-0000-000000000001',
       pk.fecha_pasada + interval '2 minutes'
FROM _pasada_k pk
JOIN montajes mo   ON mo.id_camion = pk.id_camion
                  AND mo.montado_en <= pk.fecha_pasada
                  AND (mo.desmontado_en IS NULL OR mo.desmontado_en > pk.fecha_pasada)
JOIN neumaticos n  ON n.id_neumatico = mo.id_neumatico
JOIN _calc c       ON c.serial = n.serial
WHERE c.horas_rem_ultima IS NOT NULL
ORDER BY pk.fecha_pasada, mo.posicion;

-- Extensión 3a: el OCR no leyó el serial (flanco con barro). Queda asociada al camión y la posición.
UPDATE mediciones m
SET id_neumatico = NULL, estado_identificacion = 'pendiente', metodo_identificacion = NULL, horas_operacion_neumatico = NULL
FROM _pasada_k pk
WHERE m.id_pasada = pk.id_pasada AND pk.codigo_camion = 'CAEX-105' AND pk.k = 7 AND m.posicion = 6;

-- Extensión 4a: barro sobre la banda; la lectura sale fuera de tolerancia y se descarta.
UPDATE mediciones m
SET estado_calidad = 'fuera_tolerancia',
    profundidad_mm = m.profundidad_mm + 6.4,
    motivo_descarte = 'Barro sobre la banda: la nube de puntos del escáner 3D tiene ruido. Se pide una nueva pasada con la superficie limpia.'
FROM _pasada_k pk
WHERE m.id_pasada = pk.id_pasada AND pk.codigo_camion = 'CAEX-101' AND pk.k = 7 AND m.posicion = 4;

-- -----------------------------------------------------------------------------
-- Proyecciones del modelo v1.3 (lo mismo que hace backend/app/proyeccion.py)
-- -----------------------------------------------------------------------------
INSERT INTO proyecciones (id_medicion, id_neumatico, id_version_modelo, mediciones_usadas,
                          tasa_desgaste_mm_100h, tipo_tasa, horas_remanentes, zona, creado_por, creado_en)
WITH base AS (
    SELECT m.id_medicion, m.id_neumatico, m.profundidad_mm, m.horas_operacion_neumatico AS h, pa.fecha_pasada,
           tn.umbral_retiro_mm AS umbral, tn.tasa_nominal_mm_100h AS tasa_nominal
    FROM mediciones m
    JOIN pasadas pa         ON pa.id_pasada = m.id_pasada
    JOIN neumaticos n       ON n.id_neumatico = m.id_neumatico
    JOIN tipos_neumatico tn ON tn.id_tipo_neumatico = n.id_tipo_neumatico
    WHERE m.estado_calidad = 'valida' AND m.id_neumatico IS NOT NULL
),
ventana AS (
    SELECT b.*,
           count(*)                         OVER w AS n_usadas,
           regr_slope(b.profundidad_mm, b.h)     OVER w AS pendiente,
           regr_intercept(b.profundidad_mm, b.h) OVER w AS intercepto
    FROM base b
    WINDOW w AS (PARTITION BY b.id_neumatico ORDER BY b.fecha_pasada ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
),
calculo AS (
    SELECT v.*, vm.id_version_modelo, vm.umbral_rojo_h, vm.umbral_amarillo_h,
           CASE WHEN v.n_usadas < vm.mediciones_minimas THEN 'nominal' ELSE 'observada' END AS tipo_tasa,
           CASE WHEN v.n_usadas < vm.mediciones_minimas THEN v.tasa_nominal
                WHEN v.pendiente < 0 THEN round((-v.pendiente * 100)::numeric, 2) END AS tasa,
           CASE WHEN v.n_usadas < vm.mediciones_minimas
                     THEN greatest(0, round((v.profundidad_mm - v.umbral) / v.tasa_nominal * 100))::int
                WHEN v.pendiente < 0
                     THEN greatest(0, round(((v.umbral - v.intercepto) / v.pendiente - v.h)::numeric))::int END AS horas
    FROM ventana v
    CROSS JOIN versiones_modelo vm
    WHERE vm.vigente
)
SELECT id_medicion, id_neumatico, id_version_modelo, n_usadas, tasa, tipo_tasa, horas,
       CASE WHEN horas IS NULL THEN 'sin_datos'
            WHEN horas < umbral_rojo_h THEN 'rojo'
            WHEN horas < umbral_amarillo_h THEN 'amarillo'
            ELSE 'verde' END,
       '00000000-0000-0000-0000-000000000001',
       fecha_pasada + interval '3 minutes'
FROM calculo
ORDER BY fecha_pasada;

-- -----------------------------------------------------------------------------
-- Daños detectados por el modelo de visión
-- -----------------------------------------------------------------------------
INSERT INTO danos (id_medicion, id_sensor, tipo_dano, nivel_dano, confianza, zona_neumatico, caja_delimitadora,
                   origen_deteccion, id_version_modelo, creado_por, creado_en)
SELECT m.id_medicion, s.id_sensor, d.tipo, d.nivel, d.confianza, d.zona, d.caja::jsonb,
       'modelo', vm.id_version_modelo, '00000000-0000-0000-0000-000000000001', pk.fecha_pasada + interval '2 minutes'
FROM (VALUES
  ('5980R63-2426-1348', 7, 'CAM-106', 'corte_flanco',       3, 0.94, 'flanco_externo', '{"x":0.41,"y":0.36,"ancho":0.14,"alto":0.09}'),
  ('5980R63-2328-1590', 7, 'CAM-101', 'desgaste_irregular', 2, 0.81, 'banda',          '{"x":0.22,"y":0.48,"ancho":0.46,"alto":0.12}'),
  ('5980R63-2531-1596', 7, 'CAM-103', 'roca_incrustada',    1, 0.66, 'banda',          '{"x":0.57,"y":0.52,"ancho":0.06,"alto":0.05}'),
  ('5980R63-2100-1301', 5, 'CAM-108', 'corte_banda',        1, 0.88, 'banda',          '{"x":0.33,"y":0.44,"ancho":0.08,"alto":0.03}')
) AS d(serial, k, sensor, tipo, nivel, confianza, zona, caja)
JOIN neumaticos n  ON n.serial = d.serial
JOIN mediciones m  ON m.id_neumatico = n.id_neumatico
JOIN _pasada_k pk  ON pk.id_pasada = m.id_pasada AND pk.k = d.k
JOIN sensores s    ON s.codigo_sensor = d.sensor
CROSS JOIN versiones_modelo vm
WHERE vm.vigente;

-- Humano en el bucle: el planificador sube la roca de leve a moderado.
INSERT INTO correcciones_dano (id_dano, tipo_dano_anterior, tipo_dano_nuevo, nivel_dano_anterior, nivel_dano_nuevo,
                               motivo, creado_por, creado_en)
SELECT d.id_dano, d.tipo_dano, d.tipo_dano, d.nivel_dano, 2,
       'En la foto la roca es más grande de lo que marcó el modelo y está alojada en la banda; se sube a moderado.',
       '00000000-0000-0000-0000-000000000003', '2026-09-28 09:40-03'
FROM danos d
JOIN mediciones m ON m.id_medicion = d.id_medicion
JOIN neumaticos n ON n.id_neumatico = m.id_neumatico
WHERE n.serial = '5980R63-2531-1596' AND d.tipo_dano = 'roca_incrustada';

-- -----------------------------------------------------------------------------
-- Extensión 5a: alerta de daño crítico, atendida por el despachador
-- -----------------------------------------------------------------------------
INSERT INTO alertas (tipo_alerta, prioridad, mensaje, id_camion, id_neumatico, id_medicion,
                     estado_alerta, atendida_por, atendida_en, accion_tomada, creado_por, creado_en)
SELECT 'dano_critico', 'alta',
       'Alerta de daño crítico · CAEX-102, posición 3: corte profundo en flanco. Sacar el CAEX del ciclo.',
       pk.id_camion, m.id_neumatico, m.id_medicion,
       'atendida', '00000000-0000-0000-0000-000000000004', pk.fecha_pasada + interval '15 minutes',
       'Aviso a Despacho Mina: CAEX-102 derivado a taller.',
       '00000000-0000-0000-0000-000000000001', pk.fecha_pasada + interval '3 minutes'
FROM mediciones m
JOIN _pasada_k pk ON pk.id_pasada = m.id_pasada
JOIN neumaticos n ON n.id_neumatico = m.id_neumatico
WHERE n.serial = '5980R63-2426-1348' AND pk.k = 7;

UPDATE camiones SET estado_operacional = 'derivado_a_taller' WHERE codigo_camion = 'CAEX-102';

-- -----------------------------------------------------------------------------
-- Ventanas del taller (turno A de día, turno B de noche; 3 cupos cada una)
-- -----------------------------------------------------------------------------
INSERT INTO ventanas_taller (turno, inicio, fin, cupos_totales, creado_por, creado_en) VALUES
  ('B', '2026-09-16 20:00-03', '2026-09-17 00:00-03', 3, '00000000-0000-0000-0000-000000000006', '2026-09-10 08:00-03'),
  ('A', '2026-09-20 08:00-03', '2026-09-20 12:00-03', 3, '00000000-0000-0000-0000-000000000006', '2026-09-10 08:00-03'),
  ('B', '2026-09-29 20:00-03', '2026-09-30 00:00-03', 3, '00000000-0000-0000-0000-000000000006', '2026-09-24 08:00-03'),
  ('A', '2026-09-30 08:00-03', '2026-09-30 12:00-03', 3, '00000000-0000-0000-0000-000000000006', '2026-09-24 08:00-03'),
  ('B', '2026-10-01 20:00-03', '2026-10-02 00:00-03', 3, '00000000-0000-0000-0000-000000000006', '2026-09-24 08:00-03'),
  ('A', '2026-10-02 08:00-03', '2026-10-02 12:00-03', 3, '00000000-0000-0000-0000-000000000006', '2026-09-24 08:00-03');

-- -----------------------------------------------------------------------------
-- Órdenes de trabajo. Cada una usa la última proyección disponible al emitirla.
-- El disparador registra el evento «emision» en historial_ordenes.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE _orden ON COMMIT DROP AS
SELECT o.codigo_orden, o.serial, o.tipo, o.ventana_inicio, o.emitida_en, o.alerta, o.reemplazo, o.nota
FROM (VALUES
  ('OT-2026-0047', '5980R63-2150-1355', 'inspeccion', TIMESTAMPTZ '2026-09-16 20:00-03', TIMESTAMPTZ '2026-09-15 13:10-03', false, NULL,
   'Inspección visual de la banda por desgaste disparejo informado por el operador.'),
  ('OT-2026-0064', '5980R63-2218-1478', 'inspeccion', TIMESTAMPTZ '2026-09-20 08:00-03', TIMESTAMPTZ '2026-09-19 10:00-03', false, NULL,
   'Inspección preventiva: se acerca a la zona amarilla; confirmar en terreno la tasa observada.'),
  ('OT-2026-0067', '5980R63-2426-1348', 'retiro',     TIMESTAMPTZ '2026-09-29 20:00-03', TIMESTAMPTZ '2026-09-28 08:30-03', true,  NULL,
   'Daño crítico: corte profundo en flanco. El CAEX ya fue derivado a taller por Despacho Mina.'),
  ('OT-2026-0068', '5980R63-2531-1596', 'retiro',     TIMESTAMPTZ '2026-09-29 20:00-03', TIMESTAMPTZ '2026-09-28 10:59-03', false, '5980R63-B-544', NULL),
  ('OT-2026-0069', '5980R63-2328-1590', 'retiro',     TIMESTAMPTZ '2026-09-30 08:00-03', TIMESTAMPTZ '2026-09-28 11:20-03', false, NULL,
   'Retiro por proyección y desgaste irregular confirmado en la foto.'),
  ('OT-2026-0070', '5980R63-2618-1611', 'retiro',     TIMESTAMPTZ '2026-09-30 08:00-03', TIMESTAMPTZ '2026-09-28 11:35-03', false, NULL,
   'Retiro por proyección; coordinar con el retiro de la posición 2 del mismo camión.')
) AS o(codigo_orden, serial, tipo, ventana_inicio, emitida_en, alerta, reemplazo, nota);

INSERT INTO ordenes_trabajo (codigo_orden, id_neumatico, id_proyeccion, id_ventana, id_alerta, tipo_intervencion,
                             nota, id_neumatico_reemplazo, creado_por, creado_en)
SELECT o.codigo_orden, n.id_neumatico, pr.id_proyeccion, v.id_ventana,
       CASE WHEN o.alerta THEN (SELECT a.id_alerta FROM alertas a WHERE a.id_neumatico = n.id_neumatico AND a.tipo_alerta = 'dano_critico') END,
       o.tipo,
       coalesce(o.nota,
                format('Retiro programado por proyección de %s h remanentes a la tasa %s de %s mm/100 h; banda en %s mm contra umbral de %s mm.',
                       pr.horas_remanentes, pr.tipo_tasa, replace(pr.tasa_desgaste_mm_100h::text, '.', ','),
                       replace(m.profundidad_mm::text, '.', ','), replace(tn.umbral_retiro_mm::text, '.', ','))
                || CASE WHEN o.reemplazo IS NOT NULL THEN ' Ingresa el neumático de bodega ' || o.reemplazo || '.' ELSE '' END),
       nr.id_neumatico,
       '00000000-0000-0000-0000-000000000003',
       o.emitida_en
FROM _orden o
JOIN neumaticos n       ON n.serial = o.serial
JOIN tipos_neumatico tn ON tn.id_tipo_neumatico = n.id_tipo_neumatico
JOIN ventanas_taller v  ON v.inicio = o.ventana_inicio
LEFT JOIN neumaticos nr ON nr.serial = o.reemplazo
JOIN LATERAL (
    SELECT p.* FROM proyecciones p
    WHERE p.id_neumatico = n.id_neumatico AND p.creado_en <= o.emitida_en
    ORDER BY p.creado_en DESC LIMIT 1
) pr ON true
JOIN mediciones m ON m.id_medicion = pr.id_medicion
ORDER BY o.emitida_en;

-- La OT-2026-0047 se anula (HU-F10): la orden no se borra, queda con su motivo.
UPDATE ordenes_trabajo SET estado_orden = 'anulada' WHERE codigo_orden = 'OT-2026-0047';
INSERT INTO historial_ordenes (id_orden, accion, motivo, creado_por, creado_en)
SELECT id_orden, 'anulacion', 'Error al emitir la orden: duplicaba una inspección ya programada para el mismo camión.',
       '00000000-0000-0000-0000-000000000003', '2026-09-16 09:15-03'
FROM ordenes_trabajo WHERE codigo_orden = 'OT-2026-0047';

-- La OT-2026-0064 se ejecuta.
UPDATE ordenes_trabajo SET estado_orden = 'ejecutada' WHERE codigo_orden = 'OT-2026-0064';
INSERT INTO historial_ordenes (id_orden, accion, detalle, creado_por, creado_en)
SELECT id_orden, 'ejecucion', '{"observacion": "Banda pareja y sin cortes; sigue en operación hasta su retiro programado."}'::jsonb,
       '00000000-0000-0000-0000-000000000006', '2026-09-20 11:30-03'
FROM ordenes_trabajo WHERE codigo_orden = 'OT-2026-0064';

-- La OT-2026-0069 se adelanta a la ventana del 29-09 (HU-F09). Con eso esa ventana queda llena.
INSERT INTO historial_ordenes (id_orden, accion, id_ventana_anterior, id_ventana_nueva, motivo, creado_por, creado_en)
SELECT o.id_orden, 'reprogramacion', o.id_ventana, v.id_ventana,
       'Se adelanta para aprovechar la misma detención del CAEX-106 por la OT-2026-0068.',
       '00000000-0000-0000-0000-000000000003', '2026-09-28 12:05-03'
FROM ordenes_trabajo o
JOIN ventanas_taller v ON v.inicio = '2026-09-29 20:00-03'
WHERE o.codigo_orden = 'OT-2026-0069';
UPDATE ordenes_trabajo o SET id_ventana = v.id_ventana
FROM ventanas_taller v
WHERE v.inicio = '2026-09-29 20:00-03' AND o.codigo_orden = 'OT-2026-0069';

-- Las órdenes nuevas que cree la aplicación seguirán desde OT-2026-0071.
SELECT setval('ordenes_codigo_seq', 70);

COMMIT;
