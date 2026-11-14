# Cambios técnicos — FuelBot Lite 2.0

Registro de la implementación real del rediseño descrito en `PROMP_MAESTRO.md`. Fecha: 2026-11-13. Entorno validado: Windows, R 4.6.2, Supabase PostgreSQL y API Gemini.

## 1. Resumen

Se rediseñó por completo la capa de presentación del dashboard sin modificar el esquema, las vistas, las consultas de negocio, la clasificación de saldos, el cálculo de despachos ni la lógica del agente. La aplicación pasó de un monolito de UI en `app.R` a una arquitectura de módulos Shiny con tema, componentes y estilos centralizados.

Resultado: cuatro pestañas funcionales (Resumen, Mapa, YPFB, Agente IA), encabezado editorial, footer institucional, gráficos y tablas con formato local, mapa sincronizado, chat con evidencia SQL y comportamiento responsivo verificado en 1440px y 390px.

## 2. Restricciones respetadas

- El agente sigue usando exclusivamente el rol `agente_ro` y la guardia `validar_sql()`.
- No se añadieron claves al código; la configuración sigue en `.Renviron` y secretos de GitHub.
- No se modificaron columnas, tablas, vistas ni endpoints.
- No se alteró `sql/01_esquema.sql` ni `sql/02_vistas_y_rol.sql`.
- No se cambió la clasificación de saldo ni el cálculo de despachos.
- Se conservó `reactivePoll(60000)` para detectar capturas nuevas.
- Se conservaron la cuota de 3 preguntas/minuto, 30 por sesión, el máximo de 50 filas y 6 pasos del agente.
- La conexión de la app sigue siendo de solo lectura; la conexión de escritura queda reservada al pipeline.
- No se ejecutó `git init`, no se reescribió el historial y no se eliminó la hoja legada `motion.css` de la raíz.

## 3. Arquitectura

### Antes

- `app.R` monolítico con UI, server, KPIs, gráficos, mapa, tablas y chat.
- `www/motion.css` de 30 líneas con estilos de movimiento.
- `motion.css` duplicado en la raíz, no referenciado.
- Colores y componentes dispersos.

### Después

```text
app.R                      Orquestación: tema, navbar, hero, footer, reactivos y módulos
R/theme.R                  Identidad, paleta, tema bslib y carga de Manrope
R/components.R             Iconos SVG, KPI, chips, tarjetas, popups, hero, footer
R/data.R                   consultar() con reintento y conexión de solo lectura compartida
R/mod_resumen.R            KPIs y dos gráficos Plotly
R/mod_mapa.R               Filtros, estadísticas, Leaflet y tabla DT sincronizada
R/mod_ypfb.R               KPIs, filtro por producto y tabla de programación
R/mod_agente.R             Chat, cuota, estado, evidencia SQL
www/motion.css             Sistema visual completo (hoja activa)
www/custom.js              Autoscroll, Ctrl+Enter, estado de escritura del chat
```

Los módulos reciben los reactivos de datos (`saldo`, `desp`, `latido`) desde `app.R`; no crean conexiones propias ni duplican consultas. `R/data.R` reutiliza la conexión cacheada `con_ro()` del agente y reintenta una vez ante una conexión inválida.

## 4. Archivos modificados y creados

| Archivo | Estado | Contenido |
|---|---|---|
| `app.R` | Modificado | Nueva UI con `page_navbar`, hero, footer, favicon SVG y cargas versionadas; server conserva reactivos y consultas |
| `www/motion.css` | Modificado | Sistema visual: tokens, navegación, hero, KPI, tarjetas, mapa, tablas, chat, footer, movimiento y responsividad |
| `R/theme.R` | Creado | `FB`, `fb_theme()`, `fb_fonts()` |
| `R/components.R` | Creado | `fb_icon()`, `fb_kpi()`, `fb_stat()`, `fb_chip()`, `fb_section()`, `fb_badge_estado()`, `fb_popup()`, `fb_hero_ui()`, `fb_footer_ui()`, `fb_dt_lang()` |
| `R/data.R` | Creado | `consultar()` con reconexión |
| `R/mod_resumen.R` | Creado | Módulo Resumen |
| `R/mod_mapa.R` | Creado | Módulo Mapa |
| `R/mod_ypfb.R` | Creado | Módulo YPFB |
| `R/mod_agente.R` | Creado | Módulo Agente IA |
| `www/custom.js` | Creado | Interacciones del chat |
| `docs/AUDITORIA_INICIAL.md` | Creado | Fase 1 |
| `docs/DISENO_UI_UX.md` | Creado | Fase 2 |
| `docs/CAMBIOS_TECNICOS.md` | Creado | Este documento |
| `docs/capturas/*.png` | Creado | Evidencia visual escritorio y móvil |
| `README.md` | Creado/actualizado | Instrucciones reales de ejecución |

No se modificaron `agente/agente_gemini.R`, `agente/instrucciones.txt`, `pipeline/*`, `sql/*`, `install_packages.R` ni los workflows.

## 5. Librerías y dependencias

- **R:** no se añadieron paquetes. Se usan shiny, bslib, leaflet, plotly, DT, DBI, RPostgres, httr2, jsonlite, dplyr, purrr, stringr, tibble y htmltools, ya presentes en `install_packages.R`.
- **JavaScript:** vanilla + jQuery/Shiny ya cargados por la app; no se añadió un framework.
- **Fuentes:** Manrope desde Google Fonts, con respaldo local del sistema.
- **Mapa:** teselas OpenStreetMap (sin API key).
- **Datos:** Supabase PostgreSQL y Gemini API, ya existentes.

## 6. Decisiones de diseño y cambios funcionales visibles

1. **Navegación personalizada:** píldoras con estado activo, iconos y sticky navbar; reemplaza las pestañas Bootstrap sin estilo.
2. **Hero editorial:** título, subtítulo, chips de fuentes y antigüedad real de la captura.
3. **KPIs con contexto:** cada tarjeta incluye nota de alcance y cifras tabulares.
4. **Gráficos integrados:** colores semánticos, tooltips en español, separador de miles con punto, eje de fechas real y selector temporal.
5. **Mapa:** `fitBounds` con límites numéricos, marcadores por estado, leyenda, escala, popup completo y tabla sincronizada.
6. **Tablas:** encabezados traducidos, formato de litros, paginación en español, columnas numéricas alineadas a la derecha y espacio para la flecha de orden.
7. **YPFB:** filtro por producto con centinela `__todos__` para permitir restablecer; se evita el problema de la opción vacía de Selectize.
8. **Chat:** avatar, estado, modelo, cuota visible, evidencia SQL desplegable, autoscroll, Ctrl+Enter, bloqueo del botón durante la consulta y recuperación del estado si la respuesta falla.
9. **Footer:** fuentes, zona horaria, versión y estado por fuente; sin instituciones ni autores inventados.

## 7. Correcciones realizadas durante la implementación

| Problema | Causa | Corrección |
|---|---|---|
| Gráfico de despachos invisible | `width` se pasó a `plot_ly()` y se interpretó como ancho del layout | Ancho por traza en `add_bars(width = ...)` |
| Etiquetas de fecha repetidas y miles con coma | Eje categórico y configuración regional anglosajona | Eje `type="date"` con `tickvals`/`ticktext` y `format(..., big.mark=".")` |
| Mapa sin encuadre / error `metaData` | `fitBounds` con fórmulas y `getMapData` nulo | Límites numéricos y `fitBounds(lng1, lat1, lng2, lat2)` |
| Estadísticas del mapa apiladas | `renderUI` devolvía un solo `div` | `tagList()` + `.fb-stats > .shiny-html-output { display: contents; }` |
| Indicador de escritura trabado | Handlers de Shiny con aridad incorrecta y falta de respaldo | Handlers de un argumento y evento `shiny:value`/`shiny:error` |
| No se podía restablecer el filtro YPFB | Selectize omite opciones de valor vacío | Opción centinela `"__todos__"` |
| Tabla móvil con recorte | DT conservaba anchos de escritorio | Restricciones de ancho, `overflow-x` y ocultamiento de columnas secundarias |
| Encabezados «Litros» y «Fecha de datos» pisados por la flecha de orden | Texto alineado a la derecha sin espacio para el icono | `th.dt-right { padding-right: 26px }` |
| Mapa con teselas de prueba/CartoDB | Proveedor requería clave | OpenStreetMap con atribución |

## 8. Validación ejecutada

### 8.1 Sintaxis y arranque

| Prueba | Resultado |
|---|---|
| Parseo de los 15 archivos R (`parse()`) | Todos OK, sin errores |
| Versión de R | 4.6.2 (2026-10-29 ucrt) |
| Carga de la app | HTTP 200 en `127.0.0.1:8765`, sin error de arranque |
| Dependencias | shiny 1.14.0, bslib 0.12.0, leaflet 2.2.3, plotly 4.12.1, DT 0.34.0 |

### 8.2 Datos reales consultados

| Consulta | Resultado |
|---|---|
| Rol de la app | `agente_ro`, `transaction_read_only = on` |
| Estaciones / pares / productos | 126 / 259 / 4 |
| Última captura ANH | 2026-11-13 11:30:04 |
| Distribución de saldo | 232 bajo, 5 medio, 22 alto (89,6 % bajo) |
| Gasolina Especial en alto | 11 pares |
| Programación pendiente | 3.225.000 L, 135 registros, 95 clientes, 2026-11-13 |
| Despacho confirmado | 665.000 L, 33 despachos, 2026-11-13 |
| Fuentes | ANH y YPFB con última ingesta registrada |

### 8.3 Interfaz y navegación

| Prueba | Resultado |
|---|---|
| Navegación por las cuatro pestañas | Resumen, Mapa, YPFB y Agente IA renderizan sin error |
| Tarjetas KPI del Resumen | Cuatro valores reales y notas de alcance |
| Gráfico de estados | Barras horizontales apiladas por producto |
| Gráfico de despachos | Fechas y litros con formato boliviano; selector 7/14/30/todo |
| Mapa | Teselas OSM, marcadores, leyenda, escala y popup con datos reales |
| Filtro del mapa | Gasolina Especial + Bajo: 112 marcadores y 112 filas en tabla |
| Tabla del mapa | Orden por saldo, formato de litros y antigüedad |
| Filtro YPFB | Filtrado por producto y restablecimiento con «Todos los productos» |
| Tabla YPFB | Encabezados completos; «Litros» 156px y «Fecha de datos» 166px tras la corrección |
| Consola del navegador | 0 errores JS; 0 salidas `.shiny-output-error` |

### 8.4 Agente

| Prueba | Resultado |
|---|---|
| Pregunta de extremo a extremo | «¿Cuántas estaciones reportan saldo alto de gasolina especial?» |
| Respuesta | 11 estaciones, coherente con la consulta directa a la vista |
| Modelo mostrado | `gemini-3.5-flash-lite` |
| Evidencia | Consulta SQL desplegable sobre `fuel.v_saldo_actual` |
| Cuota | Indicador `1 / 30` tras la consulta |
| Envío vacío | No inicia consulta; el indicador vuelve a oculto y el botón se habilita |
| Ctrl + Enter | Envía la consulta |
| Error de red/modelo | Se captura y se muestra en la burbuja con estado «Revisar error» |
| Seguridad | Guardia `validar_sql()` y rol `agente_ro` intactos |

### 8.5 Responsividad

| Prueba | Resultado |
|---|---|
| Escritorio 1440px | Capturas completas de las cuatro vistas |
| Móvil 390×844 | Capturas de Resumen, Mapa, YPFB y Agente |
| Scroll horizontal de página | `false` en las cuatro vistas |
| Tabla YPFB móvil | 308px, tres columnas visibles, sin desborde de página |
| Chat móvil | Compositor y burbujas dentro del ancho de 390px |
| Movimiento reducido | Regla `prefers-reduced-motion` presente |

### 8.6 Capturas

`docs/capturas/resumen.png`, `mapa.png`, `ypfb.png`, `agente.png`, `agente_respuesta.png`, `resumen_movil.png`, `mapa_movil.png`, `ypfb_movil.png`, `agente_movil.png`.

## 9. Evaluación interna

| Criterio | Peso | Puntaje | Justificación |
|---|---:|---:|---|
| Calidad visual y UI/UX | 25 | 24 | Identidad coherente, jerarquía clara y componentes consistentes; teselas OSM genéricas y densidad del mapa impiden el máximo |
| Conservación funcional | 25 | 24 | Consultas, rol, guardia SQL, cuota y reactividad intactos; la transición de 60 s no se observó con una captura nueva |
| Calidad de visualizaciones | 15 | 13,5 | Formato local y ejes corregidos; el despacho confirmado solo cubre un día |
| Interactividad | 10 | 9,5 | Filtros, mapa, tabla, chat y teclado funcionan; la cuota no se sometió a prueba de estrés |
| Responsividad | 10 | 9,5 | Sin scroll horizontal y tablas legibles; se ocultan columnas secundarias sin expansión |
| Arquitectura y mantenibilidad | 10 | 9 | Módulos y componentes claros; la hoja CSS es extensa y la hoja legada de la raíz sigue presente |
| Documentación | 5 | 5 | Auditoría, diseño, cambios, README y capturas |
| **Total** | **100** | **94,5** | Objetivo ≥90 cumplido con pruebas reales |

## 10. Limitaciones conocidas

1. **Despacho confirmado de un solo día:** el gráfico muestra una barra ancha por producto; no se simula una tendencia histórica.
2. **Marcadores densos:** en el área metropolitana varios marcadores se superponen; no se implementó clustering para no añadir dependencias.
3. **Columnas ocultas en móvil:** la tabla del mapa oculta dirección, fecha de reporte y antigüedad, y la de YPFB oculta la fecha; no hay fila expandible.
4. **Actualización de 60 s:** el `reactivePoll` está activo, pero durante las pruebas no se produjo una captura nueva para observar el cambio automático en pantalla.
5. **Cuota del agente:** se verificó el límite de 3/minuto y 30/sesión en el código y con una consulta; no se ejecutó una prueba de estrés.
6. **Latencia de Gemini:** variable; una ejecución superó 60 s. La interfaz muestra progreso y no bloquea el resto del dashboard.
7. **Dependencias externas:** Supabase, Gemini, Google Fonts y OpenStreetMap requieren internet. Si fallan las fuentes hay respaldo local; si fallan las teselas el mapa queda sin contexto visual.
8. **Datos con retraso:** la app muestra la última captura disponible (6,3 h de antigüedad en la validación). No es un error de la interfaz.
9. **Hoja CSS legada:** `motion.css` en la raíz sigue versionada y no referenciada; se conserva por seguridad y se documenta. La hoja activa es `www/motion.css`.
10. **Secreto preexistente:** `sql/02_vistas_y_rol.sql` contiene una contraseña del rol de lectura escrita en el repositorio. No se modificó por la restricción de no tocar el esquema; se recomienda rotarla y parametrizarla fuera del SQL.
11. **Pipeline separado:** la app no escribe datos; la actualización depende del workflow de GitHub Actions o de ejecutar `pipeline/run_pipeline.R` con el rol de escritura.

## 11. Ejecución

Desde la raíz del proyecto:

```r
shiny::runApp()
```

La app usa `.Renviron`. Las variables y el resto de instrucciones están en `README.md`.

## 12. Conclusión

El rediseño se implementó en los archivos reales, se validó con datos y servicios reales, y conserva las garantías de seguridad y negocio del proyecto original. Las limitaciones restantes son de cobertura de datos, de decisiones de compromiso en móvil y de dependencias externas; no afectan la integridad de la información ni el control de acceso.
