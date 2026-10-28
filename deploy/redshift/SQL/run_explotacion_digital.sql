-- ============================================================
-- run_explotacion_digital.sql
-- Corrida completa de la Explotacion Reconocer / producto DIGITAL (PP500005).
-- (repo dt / sp_rcncr_btch_rdshft_dt_chief)
-- Prerrequisitos: _strct y _pgm desplegados, en ese orden.
-- Codificacion: UTF-8 sin BOM, ASCII sin acentos.
-- ------------------------------------------------------------
-- Contrato Framework Batch: SEIS parametros VARCHAR, en este orden exacto
--   (in_solicitud, in_nit_suscriptor, in_path_archivo,
--    in_nemotecnico, in_id_facturacion, in_fecha_ejecucion)
-- En produccion los seis los pone el Framework a partir del nombre del .val y
-- de la carpeta que lo contiene; aqui se fijan para una corrida de prueba.
--
-- TRES VALORES QUE NO SON LIBRES:
--   in_path_archivo debe contener PP500005. De ahi saca el cargador el
--     producto, y de ahi saca el Builder el YAML (PP500005.yml).
--   in_nemotecnico debe casar ([\D]+val): SIN digitos antes de 'val', y
--     tener su fila en mnemotecnicos.csv o el Builder aborta con
--     NITNotFoundError.
--   in_fecha_ejecucion es YYMM, no MMYY: '0826' no existe como mes 26 y
--     deja la cadena vacia.
--
-- El .val tiene que existir en
--   s3://<bucket_origen>/PP500005digital/reconocerval1-20261028-2610.val
-- CALL NONATOMIC consistente con toda la cadena: mezclar modos produce P0001.
-- ============================================================

-- Nivel 1: carga del .val y resolucion de cada documento
CALL bdm_tempo.sp_exp_cargar_solicitud(CAST('1' AS VARCHAR(256)), CAST('9999' AS VARCHAR(256)), CAST('PP500005digital' AS VARCHAR(256)), CAST('reconocerval' AS VARCHAR(256)), CAST('20261028' AS VARCHAR(256)), CAST('2610' AS VARCHAR(256)));

-- Nivel 2: hoja "Con datos ubicacion"
CALL bdm_tempo.sp_digital_con_datos(CAST('1' AS VARCHAR(256)), CAST('9999' AS VARCHAR(256)), CAST('PP500005digital' AS VARCHAR(256)), CAST('reconocerval' AS VARCHAR(256)), CAST('20261028' AS VARCHAR(256)), CAST('2610' AS VARCHAR(256)));

-- Nivel 3: hoja "Sin datos de ubicacion"
CALL bdm_tempo.sp_digital_sin_datos(CAST('1' AS VARCHAR(256)), CAST('9999' AS VARCHAR(256)), CAST('PP500005digital' AS VARCHAR(256)), CAST('reconocerval' AS VARCHAR(256)), CAST('20261028' AS VARCHAR(256)), CAST('2610' AS VARCHAR(256)));

-- Nivel 4: hoja "Inconsistencias"
CALL bdm_tempo.sp_digital_inconsistencias(CAST('1' AS VARCHAR(256)), CAST('9999' AS VARCHAR(256)), CAST('PP500005digital' AS VARCHAR(256)), CAST('reconocerval' AS VARCHAR(256)), CAST('20261028' AS VARCHAR(256)), CAST('2610' AS VARCHAR(256)));
