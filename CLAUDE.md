# Explotacion Reconocer -- repo DT (sp_rcncr_btch_rdshft_dt_chief)

Tercero de los tres repos de despliegue a Redshift de la **Explotacion
Reconocer**: dado un `.val` con una lista de documentos, producir los CSV de
los seis productos (Esencial, Ampliado, Avanzado, Conocimiento del cliente,
Digital, Entorno).

| Orden | Repo | `type` | Que contiene |
|---|---|---|---|
| 1 | `sp_rcncr_btch_rdshft_strct_chief` | `struct` | Solo DDL: config, control y solicitud |
| 2 | `sp_rcncr_btch_rdshft_pgm_chief` | `program` | Solo procedimientos: los 18 SP y sus helpers |
| **3** | `sp_rcncr_btch_rdshft_dt_chief` | `data` | **Este.** Runners y validaciones. Produce la evidencia de QA |

**Se despliega DESPUES de `strct` y `pgm`.** Aqui no hay DDL ni
procedimientos: solo scripts que se ejecutan sentencia a sentencia.

## Que hay aqui

- `run_explotacion_<producto>.sql` x 6: la corrida completa de un producto --
  el `CALL` de carga y los tres de las hojas, con los seis argumentos
  `CAST(... AS VARCHAR(256))`.
- `validacion_explotacion_gates.sql`: un `SELECT` por gate, con nombre
  literal, veredicto `OK|FAIL|WARN` y conteo.
- `validacion_explotacion_conteos.sql`: el reparto de la solicitud, las
  causales encontradas y las filas entregadas al `UNLOAD`.

## El gate que importa es el A

`particion_sin_perdida`. Las tres hojas particionan el `.val`: cada documento
cae en exactamente un estado de `exp_solicitud_resuelta`. Si ese gate falla,
alguna hoja esta perdiendo filas, y es el unico sintoma que se va a ver.

Los demas gates cubren lo que el log de Jenkins no dice: que no quedo ninguna
corrida colgada en `en proceso`, que cada producto registro sus cuatro pasos
(carga mas tres hojas), que toda hoja completada dejo su ruta S3 escrita, y
que la configuracion minima esta puesta -- incluido `iam_role`, que el
paquete `strct` entrega vacio a proposito.

## Dos limites de los scripts de validacion

- **Solo agregados.** El informe HTML del pipeline corta a unas 12.000 celdas
  y un drill-down por documento lo revienta.
- **El conteo de columnas no se valida aqui.** Las tablas de salida son
  efimeras: cada SP las borra al terminar. Ese chequeo vive en el repo `pgm`,
  en `tools/verificar_contrato.py`, que compara numero y orden de columnas
  contra los seis Excel.

## Los runners llevan parametros de prueba

Los seis valores de cada `CALL` estan fijados para una corrida manual. En
produccion los pone el Framework a partir del nombre del `.val` y de la
carpeta que lo contiene. Tres no son libres:

- `in_path_archivo` debe contener el codigo del producto (`PP500001` ...
  `PP500006`): de ahi lo saca el cargador, y de ahi saca el Builder el YAML.
- `in_nemotecnico` debe casar `([\D]+val)`: **sin digitos antes de `val`**, y
  tener su fila en `mnemotecnicos.csv` o el Builder aborta con
  `NITNotFoundError`.
- `in_fecha_ejecucion` es **YYMM, no MMYY**: `0826` no existe como mes 26 y
  deja la cadena vacia.

El `.val` tiene que existir en
`s3://<bucket_origen>/<in_path_archivo>/<nemotecnico><solicitud>-<facturacion>-<fecha>.val`.

## El reverso de un runner no es un no-op

Los SP de explotacion no dejan staging -- lo borran ellos -- pero si dejan
filas permanentes en `exp_solicitud`, `exp_solicitud_resuelta` y
`exp_control`. El reverso de cada runner las borra con `WHERE` explicito. Los
ficheros ya escritos en S3 no se borran desde Redshift: el `UNLOAD` lleva
`ALLOWOVERWRITE` y la siguiente corrida los reescribe.

El reverso de un script de validacion si es `SELECT 1;`: no deja nada. **No se
usa `TRUNCATE`**, que sobre una tabla ausente da `42P01` y sale como
`REDSHIFT:112` en el primer despliegue.
## Reglas que no se negocian

1. **Rama `claude/quirky-cori-369c2q`.** Nunca empujar a otra sin permiso
   explicito. No crear pull requests salvo peticion expresa.
2. **La firma de los SP que invoca el Framework Batch son SEIS parametros
   VARCHAR**, en este orden: `in_solicitud`, `in_nit_suscriptor`,
   `in_path_archivo`, `in_nemotecnico` (client_id), `in_id_facturacion`
   (billing_id) e `in_fecha_ejecucion` (year_month). Los tres primeros no se
   usan en la explotacion y aun asi forman parte de la firma. El `CALL` que
   arma el Framework es POSICIONAL
   (`tf_fw_dynbtch_chief`, `step_function_definition_builder.py:93`): cambiar
   el orden cambia el significado de cada parametro.
3. **`NONATOMIC` en toda la cadena de `CALL`.** Mezclar modos rompe con
   `P0001: created in one transaction mode cannot be invoked from another`.
4. **El reverso de un procedimiento es
   `DROP PROCEDURE nombre(<firma exacta>);` SIN `IF EXISTS`** -- Redshift da
   `syntax error at or near "EXISTS"`. La firma del `DROP` repite la del
   `CREATE` caracter por caracter, y un `INOUT BIGINT` se escribe `BIGINT`.
   Tablas y vistas si usan `IF EXISTS`.
5. **UTF-8 sin BOM y ASCII sin acentos dentro de `deploy/`.** `docs/` y
   `README.md` quedan fuera a proposito (son prosa en castellano).
6. **Nunca `GRANT ... TO PUBLIC`. Nunca `DROP SCHEMA ... CASCADE`**:
   `bdm_datos` y `bdm_tempo` son compartidos.
7. **`./validar.sh` antes de empujar.** Sale distinto de cero si algo falla.

## El pipeline ejecuta DPLY DOS veces por build

`RLLBCK_PRECHECK -> DDL_1 -> DPLY -> DDL_2 -> RLLBCK_FINAL -> DDL_3 -> compare -> DPLY`

Entre las dos pasadas corre un rollback completo. Consecuencias: todo tiene
que ser idempotente (`CREATE OR REPLACE`, `CREATE TABLE IF NOT EXISTS`,
`INSERT ... WHERE NOT EXISTS`, `DELETE` acotado + `INSERT`), y la primera
pasada puede salir verde y la segunda fallar.

## El traslado a Bitbucket

GitHub es el repo de trabajo; **Bitbucket es el repo de despliegue y es el que
Jenkins construye**. Al trasladar va **solo** `deploy/redshift/` y el
`.jenkins.yml`. No van `docs/`, ni `tools/`, ni `validar.sh`, ni `README.md`,
ni este archivo.

Despues de empujar a Bitbucket, verificar el REMOTO y no el indice local:

```bash
git ls-tree -r --name-only origin/<rama> -- deploy/redshift | wc -l
```

`git ls-files` lee el indice local y no sirve: Jenkins construye lo que hay en
el remoto.

## Trampas de Redshift que el motor no avisa a tiempo

| Trampa | Que pasa |
|---|---|
| `DELTA`, `RAW`, `ENCODE`, `TOP`, `TAG`, `PERCENT`, `SYSDATE`, `DISTKEY`, `SORTKEY` son reservadas | `AS delta` compila en PostgreSQL y Redshift lo rechaza al desplegar |
| `RAISE` admite VARIABLES, no expresiones | `RAISE INFO %, COALESCE(a,b)` es error de sintaxis en el propio `CREATE` |
| Subconsulta escalar correlacionada en la lista del `SELECT` | se rechaza EN EJECUCION: `XX000: This type of correlated subquery pattern is not supported`. El despliegue pasa igual |
| `EXISTS` no vale en la lista del `SELECT` | en el `WHERE` si |
| `SUM()` sobre cero filas devuelve `NULL`, no 0 | guardar con `COUNT(*) = 0` primero |
| `ORDER BY ... DESC` pone `NULLS FIRST` por defecto | escribir `NULLS LAST` explicito |
| `COUNT(DISTINCT)` no vale como funcion de ventana | usar `MIN()/MAX() OVER` |
| `VARCHAR(n)` son n BYTES y `LEFT()` corta CARACTERES | acotar con `CAST` al ancho destino; el motor no trunca, lanza `XX000: Value too long` |
| `UPDATE ... FROM`: el destino no admite alias | |
| `REPLACE(x, NULL, '')` devuelve `NULL` | |
| `generate_series` es leader-node only | |
| El `DISTKEY` tiene que ser una columna de la lista del `SELECT`, no un alias | |
| El `CAST` de la primera rama de un `UNION ALL` fija el tipo del nodo | |
| Las UDF SQL no admiten `SELECT ... FROM` | error `0A000` |
| Una comilla simple sin escapar en un literal deja la tabla VACIA sin error | contar filas despues de desplegar |

