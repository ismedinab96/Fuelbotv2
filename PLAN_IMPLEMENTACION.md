# FuelBot Lite — Plan de implementación (R + Supabase + Gemini)

Todo en **un solo lenguaje (R)**: extracción → Supabase (PostgreSQL gratis) → dashboard Shiny con agente Gemini.
Sin Ollama, sin Python, sin Docker, sin LangGraph y sin gastar tokens de opencode para construir lo básico: el código ya está escrito en este paquete.

---

## 0. Qué encontré al revisar el repo `sociedatos/bo-combustible` (importante)

| Hallazgo | Consecuencia |
|---|---|
| Los scripts del repo (`update/*.py`) son **Python**, no R | Los reescribí en R (`pipeline/01…03`) |
| Hay **3 fuentes**: portal ANH (`abastecimiento.prod.anh.gob.bo/api/estaciones`), `consulta.ypfb.gob.bo` (JSON embebido en un `<script id="datos-publicos">`) y la API móvil de ANH | Porté las dos públicas. **No porté la API móvil** (`update.py`): usa una clave incrustada y un *user-agent* falsificado de app móvil; no lo recomiendo para un trabajo académico |
| El repo ya publica CSV semanales actualizados por un bot de GitHub Actions | Tu pipeline puede **arrancar con historial** (`backfill`) y usar el repo como respaldo |
| `data_abastecimiento` trae **`saldo_litros`** (inventario por estación) | Es un dato más rico de lo que suponía el prompt maestro |
| La Paz: 126 estaciones, ~47 400 filas de saldo (1-oct a 12-nov-2026); YPFB distrito `LPZ`: 3 839 despachos y 5 778 programaciones desde el 30-sep | Cabe de sobra en el plan gratuito de Supabase |
| ~89 % de las filas de La Paz tienen `saldo_estado = bajo` | Es un hallazgo para tu informe (y la razón de la advertencia «saldo ≠ disponibilidad») |
| Algunos textos vienen con **codificación rota** (`AURÃFERA`) | `arreglar_mojibake()` lo corrige |
| El departamento La Paz = `2` (codificación INE que usa el repo) | `DEPARTAMENTO_ID=2` en la config |

## 1. Mi opinión sobre tu propuesta

**Sí, es mejor para tu situación**, por estas razones:
1. Gemini corre en la nube: no dependes de la RAM/GPU de tu PC ni mides cuantizaciones.
2. Supabase te da PostgreSQL ya hospedado: nada de Docker.
3. Un solo lenguaje reduce errores y el trabajo de configuración.
4. Con el código listo, opencode solo hace falta para ajustes pequeños.

**Lo que cambia respecto al prompt maestro (decide con conciencia):**
- **El agente genera SQL** (como tu cuaderno), no usa herramientas parametrizadas. Compensé con 3 capas: guardia `validar_sql()`, rol `agente_ro` que **solo lee vistas** (sin permiso sobre tablas, solo lectura, timeout de 8 s) y límite de 50 filas. Probé el rol en PostgreSQL: rechaza INSERT, DROP, CREATE, lectura de tablas y consultas lentas.
- **El chatbot ya no es «local»**: las preguntas viajan a Google. Revisa los términos de la capa gratuita de Gemini y no escribas datos personales. Si tu docente exigía chatbot local, avísame.
- **Se eliminan del alcance:** crawler multipágina, grafo de enlaces/PageRank, PostGIS y motor FTS. Si tu rúbrica de Minería Web los exige, hay que añadir un módulo extra (un mini-crawler en R + `igraph` es pequeño); dímelo y lo escribo.

## 2. Arquitectura

```
ANH (API pública)  ─┐                           ┌─ Shiny (mapa, KPIs, YPFB)
YPFB (página web)  ─┼─► R: extraer → limpiar ──►  Supabase  ──► rol agente_ro ─┤
repo bo-combustible ┘   (pipeline/)    (fuel.*)   (vistas v_*)                  └─ Agente Gemini (SQL de solo lectura)
        ▲ GitHub Actions cada 2 h (opcional)
```

## 3. Paso a paso

### Paso 1 — Cuentas y requisitos (15 min)
- R ≥ 4.1 y RStudio. Cuentas gratuitas: **Supabase**, **Google AI Studio** (clave API) y **GitHub**.
- Revisa los límites vigentes del plan gratuito de cada servicio antes de empezar (cambian). Supabase pausa proyectos inactivos; la captura periódica ayuda a evitarlo.

### Paso 2 — Crear la base (15 min)
1. Supabase → *New project*. **Guarda la contraseña de la base**.
2. Botón **Connect** → pestaña de cadena de conexión → **Session pooler** (funciona con IPv4). Anota *host*, *puerto* y *usuario* (`postgres.TUREF`).
3. **SQL Editor**: pega y ejecuta `sql/01_esquema.sql`.
4. Abre `sql/02_vistas_y_rol.sql`, **cambia `CAMBIA_ESTA_CLAVE`** por una contraseña nueva y ejecútalo.
   ✔ Comprobación: *Table Editor* → esquema `fuel` muestra 7 tablas.

### Paso 3 — Configurar R (10 min)
1. Copia `.Renviron.example` como **`.Renviron`** y completa los valores. Usuario de lectura con el pooler: `agente_ro.TUREF`.
2. Clave Gemini: aistudio.google.com → *Get API key* → pégala en `GEMINI_API_KEY`.
3. Reinicia R y ejecuta `source("install_packages.R")` (una vez).
4. Prueba la conexión:
```r
source("pipeline/00_config.R", encoding = "UTF-8")
con <- con_escritura(); DBI::dbGetQuery(con, "select 1 as ok"); DBI::dbDisconnect(con)
```

### Paso 4 — Cargar el historial (10 min)
```bash
Rscript pipeline/run_pipeline.R backfill
```
Descarga los CSV semanales del repo, filtra La Paz y carga. ✔ Debe imprimir `[ok] backfill_anh: … filas` y `[ok] backfill_ypfb: … filas`. Se puede repetir sin duplicar.

### Paso 5 — Captura en vivo (10 min)
```bash
Rscript pipeline/run_pipeline.R anh
Rscript pipeline/run_pipeline.R ypfb
```
✔ Revisa `fuel.ingesta_log` en Supabase (estado `ok`) y `data/raw/` (copia cruda `.gz` con huella SHA-256).
Si un portal responde 403/500 o cambió su estructura, el pipeline lo registra como `error` y **no rompe nada**: sigue funcionando con `backfill` (repítelo a diario). No falsifiques el *user-agent* para esquivar bloqueos.

### Paso 6 — Dashboard y agente (10 min)
```r
shiny::runApp()
```
✔ Resumen con KPIs; Mapa con puntos rojos/naranjas/verdes; pestaña YPFB; pestaña Agente. Prueba: *«¿Cuántas estaciones de La Paz reportan saldo alto de gasolina especial?»* y abre «Consultas SQL ejecutadas» para ver la evidencia.
El agente elige solo un modelo Flash-Lite disponible para tu clave; para forzar uno, define `GEMINI_MODEL`.

### Paso 7 — Automatizar (20 min, opcional)
1. Sube el proyecto a GitHub (**sin** `.Renviron`; ya está en `.gitignore`).
2. *Settings → Secrets and variables → Actions*: crea `SUPABASE_HOST`, `SUPABASE_PORT`, `SUPABASE_USER`, `SUPABASE_PASSWORD`, `USER_AGENT`.
3. *Actions → Captura ANH + YPFB → Run workflow*. Ajusta el `cron` (cada 2 h por defecto) a tu cuota de minutos.
Tu pipeline queda alimentando la base sin tu computadora.

### Paso 8 — Para la defensa
Ejecuta la app local (más estable que desplegarla) y ten capturas de respaldo por si falla internet o la cuota de Gemini.

## 4. Qué hace cada archivo

| Archivo | Función |
|---|---|
| `sql/01_esquema.sql` | Tablas `fuel.*` (estaciones, saldos, ypfb_*, ingesta_log) |
| `sql/02_vistas_y_rol.sql` | Vistas `v_*` con `tipo_dato`, fechas y antigüedad + rol `agente_ro` |
| `pipeline/00_config.R` | Config, HTTP educado (reintentos, límite de ritmo), copia cruda con SHA-256, limpieza |
| `pipeline/01_extraer_anh.R` | Portal ANH → saldos y estaciones (La Paz) + validaciones |
| `pipeline/02_extraer_ypfb.R` | `consulta.ypfb.gob.bo` → despachos, programación, resumen (`LPZ`) |
| `pipeline/03_backfill_repo.R` | Historial desde los CSV del repo |
| `pipeline/04_cargar_supabase.R` | Carga idempotente (`ON CONFLICT`) y bitácora |
| `pipeline/run_pipeline.R` | Orquestador (`anh`, `ypfb`, `todo`, `backfill`) |
| `agente/agente_gemini.R` + `instrucciones.txt` | Agente con function calling: guardia SQL, bucle de pasos, reglas de evidencia |
| `app.R` + `www/motion.css` | Dashboard Shiny, chat y movimiento (ver abajo) |
| `.github/workflows/pipeline.yml` | Captura programada |

**Movimiento (tu «skill motion»):** `motion.css` define entradas con *fade* de 180–240 ms, atenuación mientras Shiny recalcula, indicador «consultando la base…» solo mientras el agente trabaja, barra de progreso con cada consulta SQL real y desactivación total con `prefers-reduced-motion`. Los KPIs dicen «hace X h» y no «en vivo»: la frecuencia real depende de la fuente.

## 5. Qué probé y qué no

**Probado aquí:** sintaxis de todos los scripts R; los parsers con **datos reales del repo** (126 estaciones, 47 397 saldos, 3 839 despachos, 5 778 programaciones, 88 resúmenes; claves sin duplicados; codificación reparada); parser YPFB con una página simulada; el SQL de carga en PostgreSQL 16 (tipos, idempotencia al repetir); las vistas; el rol `agente_ro` (ataques rechazados); la guardia SQL y el bucle del agente con Gemini simulado.

**No probado (no tengo acceso desde mi entorno):** las llamadas reales a ANH, YPFB y Gemini; la conexión a Supabase con `RPostgres`; la app Shiny en ejecución; el workflow de GitHub. Es probable que necesites un pequeño ajuste en el primer intento: pégame el mensaje de error y lo corrijo. Los nombres de modelos Gemini y las cuotas gratuitas cambian: el código detecta el modelo disponible, pero revisa tus límites en AI Studio.

## 6. Problemas frecuentes

| Síntoma | Causa probable |
|---|---|
| `Falta la variable de entorno …` | `.Renviron` sin completar o R sin reiniciar |
| No conecta a Supabase | Usa *Session pooler* y el usuario con sufijo `.TUREF`; contraseña sin espacios |
| `No encontré el bloque 'datos-publicos'` | YPFB cambió su página; usa `backfill` y avísame |
| `429` o «límite de uso gratuito» | Cuota de Gemini; espera un minuto (la app limita a 3 preguntas/min) |
| El agente responde «sin evidencia» | Revisa `v_cobertura`: quizá aún no cargaste datos de ese periodo |

## 7. Plan de 5 días

| Día | Meta |
|---|---|
| 1 | Pasos 1-5: base, historial y captura en vivo funcionando |
| 2 | Paso 6: dashboard y agente; probar 15 preguntas y anotar fallos |
| 3 | Paso 7 (automatización) + ajustar `instrucciones.txt` según fallos |
| 4 | Evaluación: 30-50 preguntas con respuesta verificable por SQL; medir exactitud y latencia **reales** |
| 5 | Informe, capturas reales y ensayo de la defensa |
