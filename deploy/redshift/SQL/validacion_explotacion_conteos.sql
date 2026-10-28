-- ============================================================
-- validacion_explotacion_conteos.sql
-- Conteos post-corrida de la Explotacion Reconocer, para evidencia de QA.
-- (repo dt / sp_rcncr_btch_rdshft_dt_chief)
-- Codificacion: UTF-8 sin BOM, ASCII sin acentos.
-- ------------------------------------------------------------
-- Solo agregados: el informe HTML del pipeline corta a unas 12.000 celdas.
-- ============================================================

-- Reparto de la solicitud entre las tres hojas, por producto.
SELECT r.solicitud,
       r.producto,
       r.estado,
       COUNT(*) AS documentos
FROM bdm_datos.exp_solicitud_resuelta r
GROUP BY r.solicitud, r.producto, r.estado
ORDER BY r.solicitud, r.producto, r.estado;

-- Causales encontradas, con su descripcion de catalogo.
SELECT r.producto,
       r.causal_codigo,
       MAX(c.descripcion) AS descripcion,
       MAX(c.bloqueante)  AS bloqueante,
       COUNT(*)           AS documentos
FROM bdm_datos.exp_solicitud_resuelta r
LEFT JOIN bdm_datos.exp_causal_inconsistencia c
  ON c.codigo = r.causal_codigo
WHERE r.causal_codigo IS NOT NULL
GROUP BY r.producto, r.causal_codigo
ORDER BY r.producto, r.causal_codigo;

-- Filas entregadas al UNLOAD por producto y hoja, con la ruta S3.
SELECT c.producto,
       c.hoja,
       c.estado,
       MAX(c.filas)   AS filas,
       MAX(c.ruta_s3) AS ruta_s3
FROM bdm_datos.exp_control c
GROUP BY c.producto, c.hoja, c.estado
ORDER BY c.producto, c.hoja;

-- Cobertura de ubicacion de los documentos que si resolvieron, por canal.
-- Dice cuantas ranuras de cada hoja van a salir pobladas de verdad.
SELECT u.clase,
       COUNT(*)                        AS ubicaciones,
       COUNT(DISTINCT u.info_basica)    AS documentos
FROM bdm_datos.exp_solicitud_resuelta r
INNER JOIN bdm_datos.mat_info_ubicacion u
  ON u.info_basica = r.info_basica
WHERE r.estado = 'CON_UBICACION'
GROUP BY u.clase
ORDER BY u.clase;
