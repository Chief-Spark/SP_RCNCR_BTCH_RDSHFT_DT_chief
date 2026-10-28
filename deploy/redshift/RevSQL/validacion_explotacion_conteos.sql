-- ============================================================
-- validacion_explotacion_conteos.sql (rollback)
-- Script de validacion: solo SELECT, no deja objetos permanentes que
-- revertir. No se usa TRUNCATE, que sobre una tabla ausente da 42P01 y sale
-- como REDSHIFT:112.
-- ============================================================

SELECT 1;
