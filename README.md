# FuelBot Lite

Plataforma académica de inteligencia energética para el departamento de La Paz, Bolivia. Dashboard en R Shiny que integra saldos reportados por la ANH, programación y despachos de YPFB, y un agente conversacional con Gemini que responde con SQL de solo lectura y evidencia desplegable.

Versión de interfaz: **2.0.0**. Última validación: 2026-11-13.

## Contenido

- [Qué incluye](#qué-incluye)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Configuración](#configuración)
- [Ejecución](#ejecución)
- [Despliegue gratuito y Bot de Telegram](#despliegue-gratuito-y-bot-de-telegram)
- [Pipeline de datos](#pipeline-de-datos)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Seguridad](#seguridad)
- [Interpretación de los datos](#interpretación-de-los-datos)
- [Validación](#validación)
- [Documentación](#documentación)
- [Limitaciones conocidas](#limitaciones-conocidas)

## Qué incluye

| Pestaña | Contenido |
|---|---|
| Resumen | KPIs de estaciones, última captura, porcentaje de saldo bajo y litros despachados; gráfico de estados por producto y de despachos por día; notas metodológicas |
| Mapa | Filtros por producto y estado, estadísticas, mapa Leaflet con popups y tabla sincronizada |
| YPFB | Programación pendiente, despacho confirmado, última fecha y tabla filtrable por producto |
| Agente IA | Chat con Gemini, cuota visible, estado del modelo y consultas SQL de evidencia |

Características transversales: encabezado editorial, navegación con iconos, footer con fuentes y estado de actualización, formato numérico boliviano, diseño responsivo y movimiento reducido para quien lo prefiera.

## Requisitos

- **R 4.6.2** (probado en Windows con `C:\Program Files\R\R-4.6.2`).
- RStudio o una consola R con el directorio de trabajo en la raíz del proyecto.
- Acceso a internet para Supabase, Gemini y las teselas del mapa.
- Una base PostgreSQL de Supabase con el esquema `fuel` y las vistas `v_*` ya existentes.
- Una clave de API de Gemini con acceso a modelos Flash-Lite.

Paquetes R: `shiny`, `bslib`, `leaflet`, `plotly`, `DT`, `DBI`, `RPostgres`, `httr2`, `jsonlite`, `dplyr`, `purrr`, `stringr`, `tibble`, `readr`, `digest`, `bit64`, `htmltools`.

No se añadieron paquetes nuevos durante el rediseño.

## Instalación

Desde la raíz del proyecto:

```r
source("install_packages.R")
```

O, si R no está en el `PATH` de Windows:

```bash
"C:\Program Files\R\R-4.6.2\bin\Rscript.exe" install_packages.R
```

## Configuración

Crea un archivo `.Renviron` en la raíz del proyecto. **No lo subas al repositorio** (ya está en `.gitignore`). R lo carga al iniciar desde esa carpeta; no uses `--vanilla`.

| Variable | Obligatoria | Uso |
|---|---|---|
| `SUPABASE_HOST` | Sí | Host del proyecto Supabase |
| `SUPABASE_PORT` | No (5432) | Puerto PostgreSQL |
| `SUPABASE_DB` | No (`postgres`) | Nombre de la base |
| `SUPABASE_RO_USER` | Sí (app) | Usuario de solo lectura, `agente_ro` |
| `SUPABASE_RO_PASSWORD` | Sí (app) | Contraseña del rol de lectura |
| `SUPABASE_USER` | Solo pipeline | Usuario de escritura |
| `SUPABASE_PASSWORD` | Solo pipeline | Contraseña del usuario de escritura |
| `GEMINI_API_KEY` | Sí (agente) | Clave de Google AI Studio |
| `GEMINI_MODEL` | No | Fuerza un modelo; si se omite, se elige un Flash-Lite disponible |
| `DEPARTAMENTO_ID` | No (`2`) | Código INE del departamento (La Paz) |
| `DISTRITOS_YPFB` | No (`LPZ`) | Distritos comerciales separados por coma |
| `USER_AGENT` | No | Identificador HTTP para las fuentes |
| `RAW_DIR` | No (`data/raw`) | Carpeta de respuestas crudas del pipeline |

Ejemplo de estructura, **sin valores reales**:

```text
SUPABASE_HOST=tu-proyecto.supabase.co
SUPABASE_PORT=5432
SUPABASE_DB=postgres
SUPABASE_RO_USER=agente_ro
SUPABASE_RO_PASSWORD=...
GEMINI_API_KEY=...
GEMINI_MODEL=gemini-3.5-flash-lite
```

En GitHub Actions, las credenciales de escritura se configuran como secretos del repositorio; el workflow `.github/workflows/pipeline.yml` las inyecta en el entorno.

## Ejecución

Desde la raíz del proyecto, en RStudio o en una consola R:

```r
shiny::runApp()
```

La aplicación abre en el puerto que indique la consola de R. También puedes abrir `ProyectoChatBot.Rproj` y ejecutar `app.R`.

La interfaz usa **solo** el rol de lectura. No necesita permisos de escritura.

### Comprobar que arrancó

- La barra superior muestra FuelBot Lite y las cuatro pestañas.
- El chip del hero muestra la antigüedad de la última captura ANH.
- El footer muestra el estado de ingesta de ANH y YPFB.
- Si aparece `s/d` o «sin registro», la conexión de lectura no está disponible o no hay datos.

## Pipeline de datos

La app no captura ni escribe datos. La actualización se realiza con el pipeline, que necesita el rol de escritura:

```bash
Rscript pipeline/run_pipeline.R anh
Rscript pipeline/run_pipeline.R ypfb
Rscript pipeline/run_pipeline.R todo
Rscript pipeline/run_pipeline.R backfill
Rscript pipeline/run_pipeline.R backfill-local RUTA/bo-combustible
```

El workflow de GitHub Actions ejecuta `todo` cada 2 horas (`17 */2 * * *`) y también puede lanzarse manualmente. Los datos crudos se guardan comprimidos en `data/raw/` con huella SHA-256.

## Estructura del proyecto

```text
app.R                     Aplicación Shiny y orquestación de módulos
R/theme.R                 Paleta, tema bslib y tipografía
R/components.R            Componentes reutilizables de interfaz
R/data.R                  consultar() y conexión de solo lectura
R/mod_resumen.R           Módulo Resumen
R/mod_mapa.R              Módulo Mapa
R/mod_ypfb.R              Módulo YPFB
R/mod_agente.R            Módulo Agente IA
agente/agente_gemini.R    Agente Gemini, guardia SQL y ejecución de consultas
agente/instrucciones.txt  System prompt del agente
pipeline/                 Extracción, backfill y carga a Supabase
sql/                      Esquema, vistas y rol de lectura
www/motion.css            Hoja de estilos activa
www/custom.js             Interacciones del chat
docs/                     Auditoría, diseño, cambios y capturas
```

`motion.css` en la raíz es una hoja legada no referenciada por la app. Se conserva por historial; la hoja activa es `www/motion.css`.

## Seguridad

- La aplicación usa el rol `agente_ro`, con `transaction_read_only = on`.
- El agente solo ejecuta `SELECT`/`WITH` de una sola sentencia, con `validar_sql()`, límite de 50 filas y 6 pasos.
- La conexión de escritura se usa únicamente en el pipeline.
- Las claves viven en `.Renviron` o en secretos de GitHub; nunca en el código.
- El chat limita a 3 preguntas por minuto y 30 por sesión.
- El agente puede equivocarse: cada respuesta incluye evidencia SQL y fechas para revisión.

El archivo `sql/02_vistas_y_rol.sql` contiene una contraseña preexistente del rol de lectura. No se modificó durante el rediseño; se recomienda rotarla y parametrizarla fuera del SQL.

## Interpretación de los datos

- **Saldo reportado (ANH):** inventario declarado por la estación. No equivale a disponibilidad ni a venta al público.
- **Despacho confirmado (YPFB):** cisterna que salió de planta hacia el distrito comercial. No implica disponibilidad en una estación.
- **Programación (YPFB):** volumen planificado que puede no haberse atendido. No se suma con el despacho confirmado.
- **Fechas:** la captura ANH se muestra en hora de Bolivia (UTC−4); la ingesta se muestra como diferencia relativa.
- **Cobertura:** la validación encontró despachos confirmados de un solo día; no se muestran tendencias históricas que los datos no respalden.
- **Estados:** bajo, medio y alto son los reportados por ANH; los umbrales no se exponen en la fuente.

## Validación

Resumen de las pruebas reales (detalle en [docs/CAMBIOS_TECNICOS.md](docs/CAMBIOS_TECNICOS.md)):

- 15 archivos R parsean sin errores; app cargada con HTTP 200.
- Rol `agente_ro` con `transaction_read_only = on`.
- 126 estaciones, 259 pares estación-producto, 4 productos; última captura 2026-11-13 11:30:04.
- 232 pares con saldo bajo, 5 medio y 22 alto; 11 pares de Gasolina Especial en alto.
- 3.225.000 L programados pendientes (135 registros, 95 clientes) y 665.000 L despachados (33 despachos).
- Navegación, filtros, mapa, tablas y agente probados en Chrome headless.
- Agente: 11 estaciones, modelo `gemini-3.5-flash-lite`, evidencia SQL, cuota `1 / 30`.
- 0 errores en consola y 0 salidas `.shiny-output-error` al recorrer las pestañas.
- Móvil 390×844 sin scroll horizontal; tabla YPFB de 308px con tres columnas.
- Capturas en [docs/capturas](docs/capturas).

Puntaje interno del rediseño: **94,5/100**, con las limitaciones documentadas.

## Despliegue gratuito y Bot de Telegram

### Por qué `shinyapps.io` y no Vercel

Vercel está orientado a sitios estáticos y funciones *serverless* (Node.js/Python), pero no ofrece un runtime nativo de R ni mantiene procesos persistentes WebSocket/PostgreSQL como los que necesita R Shiny (`app.R`). Para alojar el dashboard gratuitamente se utiliza **shinyapps.io** (plan Free).

### Desplegar el Dashboard en `shinyapps.io`

1. Crea una cuenta gratuita en [shinyapps.io](https://www.shinyapps.io/).
2. En tu panel (*Account → Tokens → Show*), obtén tu `name`, `token` y `secret` y agrégalos a tu archivo `.Renviron` local:

```text
SHINYAPPS_ACCOUNT=tu_usuario
SHINYAPPS_TOKEN=tu_token
SHINYAPPS_SECRET=tu_secret
SHINYAPPS_APP_NAME=fuelbot-lapaz
```

3. Verifica qué archivos se empaquetarán sin subir nada aún:

```bash
"C:\Program Files\R\R-4.6.1\bin\Rscript.exe" deploy_shinyapps.R --dry-run
```

4. Publica el dashboard:

```bash
"C:\Program Files\R\R-4.6.1\bin\Rscript.exe" deploy_shinyapps.R
```

El script `deploy_shinyapps.R` crea un paquete temporal con solo los archivos de la interfaz Shiny y un `.Renviron` sanitizado con **únicamente** las credenciales de solo lectura (`SUPABASE_RO_*`, `GEMINI_API_KEY` y configuración general), dejando fuera `docs/`, `data/raw/`, `sql/`, credenciales de escritura (`SUPABASE_USER`/`SUPABASE_PASSWORD`) y tokens de Telegram/shinyapps.

### Bot público de Telegram en R (`telegram/bot_telegram.R`)

El bot permite que cualquier usuario consulte al agente Gemini desde Telegram reutilizando directamente `agente/agente_gemini.R` (con la guardia `validar_sql()` y el rol de solo lectura `agente_ro`).

1. En Telegram, abre [@BotFather](https://t.me/BotFather), envía `/newbot`, sigue los pasos y copia el token generado.
2. Agrega la variable en tu `.Renviron` local (sin subirlo a GitHub):

```text
TELEGRAM_BOT_TOKEN=123456:ABC-tu-token-aqui
```

3. Verifica que el módulo cargue correctamente:

```bash
"C:\Program Files\R\R-4.6.1\bin\Rscript.exe" telegram/bot_telegram.R --check
```

4. Inicia el bot (modo *Long Polling*; no requiere IP pública ni HTTPS):

```bash
"C:\Program Files\R\R-4.6.1\bin\Rscript.exe" telegram/bot_telegram.R
```

Comandos disponibles dentro del chat de Telegram: `/start` o `/ayuda` (bienvenida y ejemplos), `/sql` (muestra las consultas SQL ejecutadas en la última pregunta) y `/limpiar` (reinicia el historial de la conversación). Para que el bot responda las 24 horas sin dejar tu PC encendida, puedes ejecutar `Rscript telegram/bot_telegram.R` en un contenedor gratuito (por ejemplo, Hugging Face Spaces con Docker o un VPS gratuito).

## Documentación

- [Auditoría inicial](docs/AUDITORIA_INICIAL.md)
- [Diseño UI/UX](docs/DISENO_UI_UX.md)
- [Cambios técnicos](docs/CAMBIOS_TECNICOS.md)
- [Capturas de pantalla](docs/capturas)

## Limitaciones conocidas

- Despacho confirmado de un solo día: el gráfico no muestra una tendencia larga.
- Marcadores densos y superpuestos en el área metropolitana; no hay clustering.
- En móvil se ocultan columnas secundarias de las tablas y no hay fila expandible.
- La actualización automática cada 60 s está activa, pero no se observó con una captura nueva durante la validación.
- La cuota del agente no se sometió a prueba de estrés.
- Gemini puede tardar más de 60 s; la interfaz muestra progreso.
- Supabase, Gemini, Google Fonts y OpenStreetMap son dependencias externas.
- La app muestra la última captura disponible; puede tener horas de antigüedad.
- `motion.css` de la raíz es legado no referenciado.
- La contraseña preexistente en `sql/02_vistas_y_rol.sql` debe rotarse.

## Licencia y autoría

No se declara una licencia ni autoría institucional en este repositorio. La plataforma se presenta como académica y no atribuye responsabilidad a ANH, YPFB ni a ninguna otra institución.
