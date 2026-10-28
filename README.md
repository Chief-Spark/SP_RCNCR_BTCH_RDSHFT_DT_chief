# SP_RCNCR_BTCH_RDSHFT_DT_chief — Explotación Reconocer

Paquete **`type: data`**, **`order: 3`**. Tercero de los tres repositorios de
despliegue a Redshift de la Explotación Reconocer. **Se despliega después de
`strct` y `pgm`.** Aquí no hay DDL ni procedimientos: solo scripts que se
ejecutan sentencia a sentencia, y es el repositorio que produce la evidencia
de QA.

## Orden de despliegue (`deploy.par`)

| # | Script | Qué hace |
|---|---|---|
| 1-6 | `run_explotacion_<producto>.sql` | corrida completa de un producto: el `CALL` de carga y los tres de las hojas |
| 7 | `validacion_explotacion_conteos.sql` | reparto de la solicitud, causales y filas entregadas al `UNLOAD` |
| 8 | `validacion_explotacion_gates.sql` | siete gates con veredicto `OK`/`FAIL`/`WARN` |

Los seis productos: `esencial` (`PP500001`), `ampliado` (`PP500002`),
`avanzado` (`PP500003`), `conocimiento_cliente` (`PP500004`), `digital`
(`PP500005`) y `entorno` (`PP500006`).

## Post-merge en Jenkins

1. `strct` → `pgm` → `dt`, en ese orden.
2. Poner `iam_role` en `bdm_datos.exp_config`: el paquete `strct` lo entrega
   vacío a propósito.
3. Dejar el `.val` en
   `s3://<bucket_origen>/<carpeta_del_producto>/<nemotecnico><solicitud>-<facturacion>-<fecha>.val`
4. Ejecutar `run_explotacion_<producto>.sql`.
5. Validar con `validacion_explotacion_gates.sql`.

## El gate que importa es el A

`particion_sin_perdida`. Las tres hojas **particionan** el `.val`: cada
documento cae en exactamente un estado de `exp_solicitud_resuelta`
(`CON_UBICACION`, `SIN_UBICACION` o `INCONSISTENTE`). Si ese gate falla,
alguna hoja está perdiendo filas, y es el único síntoma que se va a ver.

Los otros seis cubren lo que el log de Jenkins no dice: que no quedó ninguna
corrida colgada en `en proceso`, que cada producto registró sus cuatro pasos
(carga más tres hojas), que toda hoja completada dejó su ruta S3 escrita, que
toda fila inconsistente trae causal de catálogo, que no apareció un cuarto
estado, y que la configuración mínima está puesta.

## Dos límites de las validaciones

- **Solo agregados.** El informe HTML del pipeline corta a unas 12.000 celdas
  y un drill-down por documento lo revienta.
- **El conteo de columnas no se valida aquí.** Las tablas de salida son
  efímeras: cada SP las borra al terminar. Ese chequeo vive en el repo `pgm`,
  en `tools/verificar_contrato.py`, que compara número y orden de columnas
  contra los seis Excel.

## Los runners llevan parámetros de prueba

En producción los seis argumentos los pone el Framework a partir del nombre
del `.val` y de la carpeta que lo contiene. Tres no son libres:

- `in_path_archivo` debe contener el código del producto (`PP500001` …
  `PP500006`): de ahí lo saca el cargador, y de ahí saca el Builder el YAML.
- `in_nemotecnico` debe casar `([\D]+val)` — **sin dígitos antes de `val`** —
  y tener su fila en `mnemotecnicos.csv`, o el Builder aborta con
  `NITNotFoundError`.
- `in_fecha_ejecucion` es **YYMM, no MMYY**: `0826` no existe como mes 26 y
  deja la cadena vacía.

## El reverso de un runner no es un no-op

Los SP de explotación no dejan staging — lo borran ellos — pero sí dejan filas
permanentes en `exp_solicitud`, `exp_solicitud_resuelta` y `exp_control`. El
reverso de cada runner las borra con `WHERE` explícito. Los ficheros ya
escritos en S3 no se borran desde Redshift: el `UNLOAD` lleva
`ALLOWOVERWRITE` y la siguiente corrida los reescribe.

## Antes de empujar

```bash
./validar.sh
```

## Traslado a Bitbucket

GitHub es el repositorio de trabajo; **Bitbucket es el de despliegue y es el que
Jenkins construye**. Al trasladar viaja **solo**:

```
deploy/redshift/
.jenkins.yml
```

No viajan `docs/`, `tools/`, `validar.sh`, `README.md` ni `CLAUDE.md`.

Después de empujar a Bitbucket, verifica el **remoto**, no el índice local:

```bash
git ls-tree -r --name-only origin/<rama> -- deploy/redshift | wc -l
```

`git ls-files` lee tu índice local y **no sirve**: Jenkins construye lo que hay
en el remoto.

El orden de despliegue en Jenkins es `strct` → `pgm` → `dt`, y no es una
convención: si se invierte, el `CREATE PROCEDURE` pasa igual (Redshift difiere
la semántica) y revienta en la primera invocación con
`relation ... does not exist`.

## Documentación

- `CLAUDE.md` — bitácora: convenciones, trampas de Redshift y decisiones
  tomadas.
- El mapa de las 869 columnas de los seis Excel está en el repo `pgm`, en
  `docs/MAPA_COLUMNAS.md`.
