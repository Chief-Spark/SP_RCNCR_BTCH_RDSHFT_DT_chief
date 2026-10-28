-- ============================================================
-- validacion_explotacion_gates.sql
-- Gates post-corrida de la Explotacion Reconocer.
-- (repo dt / sp_rcncr_btch_rdshft_dt_chief)
-- Un SELECT por gate, con nombre literal, veredicto OK|FAIL|WARN y conteo.
-- Sin DML: Jenkins captura la rejilla como evidencia HTML.
-- Codificacion: UTF-8 sin BOM, ASCII sin acentos.
-- ------------------------------------------------------------
-- SOLO AGREGADOS, a proposito: el informe HTML del pipeline corta a unas
-- 12.000 celdas y un drill-down por documento lo revienta.
--
-- El gate que de verdad prueba el entregable es el A: las tres hojas
-- particionan el .val, asi que su suma tiene que ser el total de documentos
-- pedidos, sin solape y sin perdida.
-- ============================================================

-- Gate A: la particion cuadra. exp_solicitud (lo que pidio el cliente) tiene
-- exactamente las mismas filas que exp_solicitud_resuelta (lo que se
-- clasifico), por solicitud y producto.
SELECT 'particion_sin_perdida' AS gate,
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FAIL' END AS resultado,
       COUNT(*) AS filas
FROM (
    SELECT s.solicitud, s.producto, COUNT(*) AS pedidos
      FROM bdm_datos.exp_solicitud s
     GROUP BY s.solicitud, s.producto
) ped
LEFT JOIN (
    SELECT r.solicitud, r.producto, COUNT(*) AS resueltos
      FROM bdm_datos.exp_solicitud_resuelta r
     GROUP BY r.solicitud, r.producto
) res
  ON  res.solicitud = ped.solicitud
  AND res.producto  = ped.producto
WHERE ped.pedidos <> COALESCE(res.resueltos, 0);

-- Gate B: ningun estado fuera de los tres del contrato. Un cuarto estado
-- significa que una hoja se quedaria sin esas filas y nadie se enteraria.
SELECT 'estados_del_contrato' AS gate,
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FAIL' END AS resultado,
       COUNT(*) AS filas
FROM bdm_datos.exp_solicitud_resuelta r
WHERE r.estado NOT IN ('CON_UBICACION', 'SIN_UBICACION', 'INCONSISTENTE');

-- Gate C: toda fila INCONSISTENTE trae causal, y la causal esta en catalogo.
-- Si falla, la hoja de Inconsistencias sale con ESTADO y CAUSAL vacios.
SELECT 'inconsistencias_con_causal' AS gate,
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FAIL' END AS resultado,
       COUNT(*) AS filas
FROM bdm_datos.exp_solicitud_resuelta r
LEFT JOIN bdm_datos.exp_causal_inconsistencia c
  ON c.codigo = r.causal_codigo
WHERE r.estado = 'INCONSISTENTE'
  AND c.codigo IS NULL;

-- Gate D: ninguna corrida quedo fallida ni colgada en 'en proceso'.
SELECT 'corridas_completadas' AS gate,
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FAIL' END AS resultado,
       COUNT(*) AS filas
FROM bdm_datos.exp_control c
WHERE c.estado <> 'completado';

-- Gate E: cada producto con corrida tiene sus cuatro pasos registrados
-- (CARGA mas las tres hojas). Menos de cuatro = un nivel que no llego a
-- ejecutarse, y el Glue consolidaria una salida de menos.
SELECT 'cuatro_pasos_por_producto' AS gate,
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FAIL' END AS resultado,
       COUNT(*) AS filas
FROM (
    SELECT c.solicitud, c.producto, COUNT(DISTINCT c.hoja) AS pasos
      FROM bdm_datos.exp_control c
     GROUP BY c.solicitud, c.producto
) t
WHERE t.pasos <> 4;

-- Gate F: toda corrida de hoja dejo su ruta S3 escrita. Sin ruta no hubo
-- UNLOAD, y el Glue no encontrara la carpeta.
SELECT 'ruta_s3_registrada' AS gate,
       CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'FAIL' END AS resultado,
       COUNT(*) AS filas
FROM bdm_datos.exp_control c
WHERE c.hoja IN ('CONDATOS', 'SINDATOS', 'INCONSIS')
  AND c.estado = 'completado'
  AND NULLIF(TRIM(COALESCE(c.ruta_s3, '')), '') IS NULL;

-- Gate G: la configuracion minima esta puesta. iam_role se entrega vacio a
-- proposito, asi que este gate es el recordatorio de que hay que ponerlo.
-- COUNT(DISTINCT parametro) y no COUNT(*): un parametro puede estar en la
-- fila del ambiente y en la de 'TODOS', y contarlo dos veces daria OK con
-- cuatro parametros puestos.
SELECT 'config_minima' AS gate,
       CASE WHEN COUNT(DISTINCT c.parametro) = 5 THEN 'OK' ELSE 'FAIL' END AS resultado,
       COUNT(DISTINCT c.parametro) AS filas
FROM bdm_datos.exp_config c
WHERE c.parametro IN ('bucket_origen', 'bucket_salida', 'iam_role',
                      'delimitador', 'prefijo_salida')
  AND NULLIF(TRIM(COALESCE(c.valor, '')), '') IS NOT NULL
  AND c.ambiente IN (current_database(), 'TODOS');
