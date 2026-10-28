-- ============================================================
-- run_explotacion_conocimiento_cliente.sql (rollback)
-- Deja la corrida de prueba de CONOCIMIENTO DEL CLIENTE como si no hubiera pasado.
-- Los SP de explotacion no dejan staging (lo borran ellos), pero si dejan
-- filas permanentes en exp_solicitud, exp_solicitud_resuelta y exp_control.
-- Todo DELETE de nivel superior lleva WHERE explicito: sin el, el despliegue
-- falla con REDSHIFT:232.
-- Los ficheros ya escritos en S3 no se borran desde Redshift; el UNLOAD lleva
-- ALLOWOVERWRITE y la siguiente corrida los reescribe.
-- ============================================================

DELETE FROM bdm_datos.exp_solicitud_resuelta
 WHERE solicitud = '1' AND producto = 'PP500004';

DELETE FROM bdm_datos.exp_solicitud
 WHERE solicitud = '1' AND producto = 'PP500004';

DELETE FROM bdm_datos.exp_control
 WHERE solicitud = '1' AND producto = 'PP500004';
