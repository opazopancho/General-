-- =============================================================================
-- PRIORIZACIÓN REVISADA Y AVISO DE IA · Pórtico dimensional predictivo de neumáticos CAEX
-- Equipo 3 · USACH · Semana 6 (clase 4.1, ética y sostenibilidad)
--
-- Documento que explica este cambio: docs/etica.md, sección 3.1 y 3.3.
--
-- Qué corrige:
--   1. Antes, el tablero ordenaba por horas remanentes y dejaba al final a los
--      neumáticos sin datos. Una ausencia de datos no es una buena noticia: ahora
--      sube al grupo «revisar el dato», justo después de los rojos.
--   2. También sube lo que el pórtico no logró medir bien: serial no leído
--      (extensión 3a), medición descartada (4a) o un camión que dejó de pasar.
--   3. Cada fila dice por qué quedó en ese lugar (motivo_prioridad) y qué parte
--      del dato viene de un modelo (origen_estimacion, origen_dano). Así la
--      pantalla puede avisar cuándo interviene IA sin inventar el texto.
--
-- Se aplica después de 20261014120000_estructura_datos_preliminar.sql.
-- Es re-ejecutable.
-- =============================================================================

-- Configuración nueva de la versión del modelo: cuántos días puede un camión
-- quedar sin pasar por el pórtico antes de que sus datos se consideren atrasados.
ALTER TABLE versiones_modelo
    ADD COLUMN IF NOT EXISTS dias_max_sin_pasar smallint NOT NULL DEFAULT 3 CHECK (dias_max_sin_pasar > 0);
COMMENT ON COLUMN versiones_modelo.dias_max_sin_pasar IS
    'Días de atraso respecto de la última captura del pórtico a partir de los cuales los datos de un camión se marcan como atrasados.';

-- Las vistas dependientes se recrean porque cambian columnas.
DROP VIEW IF EXISTS v_camiones_resumen;
DROP VIEW IF EXISTS v_tablero_turno;

-- P1 · Tablero del turno con la priorización revisada.
-- Grupos, del más urgente al menos urgente:
--   1 Daño crítico           nivel de daño 3, aunque el modelo de desgaste diga verde (HU-F06)
--   2 Zona roja              menos horas que el umbral rojo
--   3 Revisar el dato        sin mediciones, serial no leído, medición descartada, dos o más pasadas
--                            seguidas sin medición válida, o camión que no pasa por el pórtico
--   4 Zona amarilla
--   5 Verde con estimación débil   la tasa es nominal: todavía no hay historial suficiente
--   6 Verde
CREATE VIEW v_tablero_turno WITH (security_invoker = true) AS
WITH ref AS (
    SELECT max(fecha_pasada) AS ultima_captura_portico FROM pasadas
),
vm AS (
    SELECT * FROM versiones_modelo WHERE vigente
),
base AS (
    SELECT ca.id_camion, ca.codigo_camion, mo.posicion,
           n.id_neumatico, n.serial, tn.marca,
           um.codigo_medicion, um.profundidad_mm, um.temperatura_flanco_c, um.fecha_pasada,
           up.tasa_desgaste_mm_100h, up.tipo_tasa, up.horas_remanentes, up.mediciones_usadas,
           coalesce(up.zona, 'sin_datos') AS zona,
           up.modelo_version,
           coalesce(nd.nivel_dano, 0) AS nivel_dano,
           nd.confianza_minima_dano,
           coalesce(nd.hay_por_confirmar, false) AS dano_por_confirmar,
           coalesce(nd.hay_corregido, false)     AS dano_corregido,
           up_cam.fecha_ultima_pasada_camion,
           (SELECT count(*) FROM pasadas p2
             WHERE p2.id_camion = ca.id_camion
               AND p2.fecha_pasada > coalesce(um.fecha_pasada, mo.montado_en)
               AND p2.fecha_pasada >= mo.montado_en)                        AS pasadas_sin_medicion_valida,
           (SELECT m3.estado_identificacion FROM mediciones m3 JOIN pasadas p3 ON p3.id_pasada = m3.id_pasada
             WHERE p3.id_camion = ca.id_camion AND m3.posicion = mo.posicion AND p3.fecha_pasada >= mo.montado_en
             ORDER BY p3.fecha_pasada DESC LIMIT 1)                         AS identificacion_ultima_pasada,
           (SELECT m4.estado_calidad FROM mediciones m4 JOIN pasadas p4 ON p4.id_pasada = m4.id_pasada
             WHERE p4.id_camion = ca.id_camion AND m4.posicion = mo.posicion AND p4.fecha_pasada >= mo.montado_en
             ORDER BY p4.fecha_pasada DESC LIMIT 1)                         AS calidad_ultima_pasada,
           extract(day FROM ref.ultima_captura_portico - up_cam.fecha_ultima_pasada_camion)::int AS dias_sin_pasar,
           vm.dias_max_sin_pasar
    FROM montajes mo
    CROSS JOIN ref
    CROSS JOIN vm
    JOIN camiones ca        ON ca.id_camion = mo.id_camion
    JOIN neumaticos n       ON n.id_neumatico = mo.id_neumatico
    JOIN tipos_neumatico tn ON tn.id_tipo_neumatico = n.id_tipo_neumatico
    LEFT JOIN LATERAL (
        SELECT max(pa.fecha_pasada) AS fecha_ultima_pasada_camion FROM pasadas pa WHERE pa.id_camion = ca.id_camion
    ) up_cam ON true
    LEFT JOIN LATERAL (
        SELECT m.id_medicion, m.codigo_medicion, m.profundidad_mm, m.temperatura_flanco_c, pa.fecha_pasada
        FROM mediciones m JOIN pasadas pa ON pa.id_pasada = m.id_pasada
        WHERE m.id_neumatico = n.id_neumatico AND m.estado_calidad = 'valida' AND pa.fecha_pasada >= mo.montado_en
        ORDER BY pa.fecha_pasada DESC LIMIT 1
    ) um ON true
    LEFT JOIN LATERAL (
        SELECT pr.tasa_desgaste_mm_100h, pr.tipo_tasa, pr.horas_remanentes, pr.zona, pr.mediciones_usadas, v.modelo_version
        FROM proyecciones pr JOIN versiones_modelo v ON v.id_version_modelo = pr.id_version_modelo
        WHERE pr.id_medicion = um.id_medicion
        ORDER BY pr.creado_en DESC LIMIT 1
    ) up ON true
    LEFT JOIN LATERAL (
        SELECT max(dv.nivel_dano) AS nivel_dano,
               min(dv.confianza) FILTER (WHERE dv.nivel_dano > 0 AND NOT dv.corregido) AS confianza_minima_dano,
               bool_or(dv.por_confirmar AND dv.nivel_dano > 0) AS hay_por_confirmar,
               bool_or(dv.corregido) AS hay_corregido
        FROM v_danos_vigentes dv WHERE dv.id_medicion = um.id_medicion
    ) nd ON true
    WHERE mo.desmontado_en IS NULL
),
clasificado AS (
    SELECT b.*,
           (b.zona = 'sin_datos'
            OR b.identificacion_ultima_pasada IN ('pendiente', 'verificacion_manual')
            OR b.calidad_ultima_pasada IN ('fuera_tolerancia', 'rechazada')
            OR b.pasadas_sin_medicion_valida >= 2
            OR b.dias_sin_pasar > b.dias_max_sin_pasar) AS revisar_dato,
           CASE
               WHEN b.nivel_dano = 3 THEN 1
               WHEN b.zona = 'rojo' THEN 2
               WHEN b.zona = 'sin_datos'
                 OR b.identificacion_ultima_pasada IN ('pendiente', 'verificacion_manual')
                 OR b.calidad_ultima_pasada IN ('fuera_tolerancia', 'rechazada')
                 OR b.pasadas_sin_medicion_valida >= 2
                 OR b.dias_sin_pasar > b.dias_max_sin_pasar THEN 3
               WHEN b.zona = 'amarillo' THEN 4
               WHEN b.tipo_tasa = 'nominal' THEN 5
               ELSE 6
           END AS grupo_prioridad
    FROM base b
)
SELECT row_number() OVER (ORDER BY c.grupo_prioridad, c.horas_remanentes ASC NULLS FIRST, c.dias_sin_pasar DESC, c.codigo_camion, c.posicion) AS prioridad,
       c.grupo_prioridad,
       CASE c.grupo_prioridad
           WHEN 1 THEN 'Daño crítico (nivel 3)' || CASE WHEN c.dano_por_confirmar THEN ', por confirmar en terreno' ELSE '' END
           WHEN 2 THEN 'Zona roja: ' || c.horas_remanentes || ' h hasta el umbral de retiro'
           WHEN 3 THEN 'Revisar el dato: ' || concat_ws('; ',
                    CASE WHEN c.zona = 'sin_datos' THEN 'sin mediciones válidas desde el montaje' END,
                    CASE WHEN c.identificacion_ultima_pasada IN ('pendiente', 'verificacion_manual') THEN 'serial no leído en la última pasada' END,
                    CASE WHEN c.calidad_ultima_pasada IN ('fuera_tolerancia', 'rechazada') THEN 'última medición descartada por calidad' END,
                    CASE WHEN c.zona <> 'sin_datos' AND c.pasadas_sin_medicion_valida >= 2 THEN c.pasadas_sin_medicion_valida || ' pasadas seguidas sin medición válida' END,
                    CASE WHEN c.dias_sin_pasar > c.dias_max_sin_pasar THEN 'el camión no pasa por el pórtico hace ' || c.dias_sin_pasar || ' días' END)
           WHEN 4 THEN 'Zona amarilla: ' || c.horas_remanentes || ' h hasta el umbral de retiro'
           WHEN 5 THEN 'Verde, pero estimado con tasa nominal: falta historial'
           ELSE 'Verde: ' || c.horas_remanentes || ' h hasta el umbral de retiro'
       END AS motivo_prioridad,
       CASE
           WHEN c.horas_remanentes IS NULL THEN 'Sin estimación: no hay mediciones válidas para proyectar'
           WHEN c.tipo_tasa = 'nominal' THEN 'Estimación del modelo ' || c.modelo_version || ' con tasa nominal del tipo de neumático (referencial)'
           ELSE 'Estimación del modelo ' || c.modelo_version || ' con tasa observada en ' || c.mediciones_usadas || ' mediciones'
       END AS origen_estimacion,
       CASE
           WHEN c.nivel_dano = 0 AND NOT c.dano_corregido THEN NULL
           WHEN c.dano_corregido THEN 'Clasificación revisada por una persona'
           WHEN c.dano_por_confirmar THEN 'Detectado por IA con confianza ' || round(c.confianza_minima_dano * 100) || ' %: por confirmar'
           ELSE 'Detectado por IA con confianza ' || round(c.confianza_minima_dano * 100) || ' %'
       END AS origen_dano,
       c.revisar_dato,
       c.id_camion, c.codigo_camion, c.posicion, c.id_neumatico, c.serial, c.marca,
       c.codigo_medicion, c.profundidad_mm, c.temperatura_flanco_c, c.fecha_pasada,
       c.tasa_desgaste_mm_100h, c.tipo_tasa, c.horas_remanentes, c.zona, c.modelo_version,
       c.nivel_dano, c.dano_por_confirmar, c.pasadas_sin_medicion_valida, c.dias_sin_pasar
FROM clasificado c;

COMMENT ON VIEW v_tablero_turno IS
    'P1 Tablero del turno con priorización revisada (docs/etica.md 3.1): daño crítico, rojo, revisar el dato, amarillo, verde con tasa nominal, verde. Incluye el motivo de cada lugar y el origen de cada estimación para el aviso de IA.';

-- Camiones (HU-03, HU-F03): se agrega cuántas posiciones tienen el dato en duda.
CREATE VIEW v_camiones_resumen WITH (security_invoker = true) AS
SELECT ca.id_camion,
       ca.codigo_camion,
       ca.modelo_camion,
       ca.estado_operacional,
       up.horometro_h,
       up.fecha_pasada AS fecha_ultima_pasada,
       count(*) FILTER (WHERE t.zona = 'rojo' OR t.nivel_dano = 3) AS cantidad_neumaticos_criticos,
       coalesce(max(t.nivel_dano), 0)                            AS nivel_dano_camion,
       count(*) FILTER (WHERE t.zona = 'sin_datos')              AS posiciones_sin_datos,
       count(*) FILTER (WHERE t.revisar_dato)                    AS posiciones_por_revisar
FROM camiones ca
LEFT JOIN v_tablero_turno t ON t.id_camion = ca.id_camion
LEFT JOIN LATERAL (
    SELECT pa.horometro_h, pa.fecha_pasada FROM pasadas pa
    WHERE pa.id_camion = ca.id_camion ORDER BY pa.fecha_pasada DESC LIMIT 1
) up ON true
GROUP BY ca.id_camion, ca.codigo_camion, ca.modelo_camion, ca.estado_operacional, up.horometro_h, up.fecha_pasada;

COMMENT ON VIEW v_camiones_resumen IS 'Camiones: horómetro, última pasada, neumáticos críticos, peor nivel de daño y posiciones con el dato en duda.';

-- Los permisos de las vistas siguen a las tablas (security_invoker): no hay que repetir políticas.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        GRANT SELECT ON v_tablero_turno, v_camiones_resumen TO anon, authenticated;
    END IF;
END $$;
