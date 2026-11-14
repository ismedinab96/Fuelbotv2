# Auditoría inicial — FuelBot Lite

Fecha de auditoría: 2026-11-13. Entorno: Windows, R 4.6.2, proyecto `ProyectoChatBot`.

## 1. Arquitectura encontrada

| Elemento | Estado real |
|---|---|
| `app.R` | Monolito de 126 líneas: UI, server, KPIs, gráficos, mapa, tabla YPFB y chat en un solo archivo. |
| `www/motion.css` | Hoja activa (la app la enlaza como `motion.css`). 30 líneas, movimiento discreto. |
| `motion.css` (raíz) | Copia idéntica **no referenciada** por la app. Duplicación de mantenimiento. |
| `pipeline/00_config.R` | Configuración, HTTP educado, limpieza y conexiones `con_escritura()` / `con_lectura()`. |
| `agente/agente_gemini.R` | Agente Gemini con function calling, guardia `validar_sql()` y conexión `agente_ro`. |
| `sql/01_esquema.sql`, `sql/02_vistas_y_rol.sql` | Esquema `fuel`, vistas `v_*` y rol de solo lectura. |
| Reactividad | `reactivePoll(60000)` sobre `max(fecha_captura)` y `count(*)` de `fuel.v_saldo_actual`. |
| Dependencias | `shiny`, `bslib`, `leaflet`, `plotly`, `DT` + capa de datos (`DBI`, `RPostgres`, `httr2`, `jsonlite`, `dplyr`, `purrr`, `stringr`, `tibble`, `htmltools`). |

Versiones verificadas: shiny 1.14.0, bslib 0.12.0, leaflet 2.2.3, plotly 4.12.1, DT 0.34.0.
No están instaladas: `shinyjs`, `shinyWidgets`, `echarts4r`, `fresh`, `networkD3`, `bsicons`.

## 2. Acceso a datos comprobado

La conexión con el rol de solo lectura funciona desde este entorno. Consultas de inspección (sin modificar nada):

| Dato | Valor observado |
|---|---|
| Estaciones con datos en `v_saldo_actual` | 126 |
| Pares estación-producto | 259 |
| Última captura ANH | 2026-11-13 11:30:04 (hora Bolivia) |
| Antigüedad del reporte en el momento de la auditoría | 5,7 h |
| Productos | Gasolina Especial, Diésel Oil, Gasolina Premium, Diésel ULS |
| Programación YPFB pendiente (última fecha) | 135 registros, 2026-11-13 |
| Despachos YPFB confirmados (última fecha) | 33 registros, 2026-11-13 |
| `producto_general` en YPFB | `Gasolina` y `Diesel` (dos series) |
| Cobertura `v_cobertura` | saldos y YPFB solo con datos del día auditado |

Conclusión: los datos alcanzan para KPIs, mapa y tablas reales. No hay base para comparaciones porcentuales históricas ni para gráficos de flujo si la cobertura sigue limitada a un día; no se inventarán.

## 3. Componentes existentes

- 4 `value_box()` para KPIs.
- 2 gráficos Plotly (barras apiladas de estado y de despachos).
- Mapa Leaflet con `addTiles()`, `addCircleMarkers()` y `addLegend()`.
- Tabla DT sincronizada con el producto del mapa.
- Tabla DT de programación pendiente YPFB.
- Chat propio con burbujas, indicador de escritura, historial de 3 turnos, cuota 3/min y 30/sesión, y SQL desplegable.
- Barra de progreso de Shiny durante el trabajo del agente.

## 4. Problemas visuales detectados

1. No existe encabezado editorial ni footer institucional.
2. Navegación con pestañas Bootstrap sin personalización; el color primario (`#0f6e56`) no pertenece a la identidad solicitada.
3. KPIs sin iconografía, sin contexto temporal en el cuerpo y con jerarquía tipográfica débil.
4. Gráficos con estilos Plotly por defecto (colores, fuentes, leyendas y tooltips sin tratamiento).
5. Mapa con teselas genéricas, marcadores básicos, popups sin diseño y sin resumen del filtro activo.
6. Tablas DT sin formato numérico de litros ni traducción de controles.
7. Chat funcional pero visualmente plano: sin avatar, estado, modelo, cuota visible ni jerarquía de evidencia SQL.
8. CSS duplicado en raíz y en `www/`, con colores dispersos y sin variables centralizadas.
9. Sin ajustes específicos de responsividad para mapa, chat, KPIs ni footer.

## 5. Riesgos funcionales y de seguridad

| Riesgo | Impacto | Tratamiento |
|---|---|---|
| Contraseña del rol `agente_ro` escrita en `sql/02_vistas_y_rol.sql` | Secreto versionado en el repositorio | **No se modifica el esquema** en este rediseño; se documenta y se recomienda rotar la clave y parametrizarla. |
| Consultas SQL del dashboard y del agente | Pueden romperse si se cambian columnas | Se conservan las consultas existentes; las nuevas usan solo vistas y columnas ya presentes. |
| Actualización cada 60 s | Debe seguir operando | Se conserva `reactivePoll(60000)` y las mismas consultas de KPIs. |
| Cuota Gemini | El agente debe seguir limitado | Se conservan 3 preguntas/min y 30 por sesión. |
| `v_fuentes.ultima_ingesta_ok` es `timestamptz` y `fecha_captura` es `timestamp` sin zona | Diferencias de 4 h si se mezclan | Se muestra la captura ANH como hora local de Bolivia y la ingesta como diferencia relativa (`hace X h`). |
| Cobertura histórica limitada | No permite tendencias largas ni comparaciones programación vs despacho | Se documenta como limitación; los gráficos se limitan a lo disponible. |
| Teselas y tipografía externas | Requieren internet en tiempo de ejecución | Se mantienen teselas con atribución y se define una pila de fuentes de respaldo. |
| R no está en el `PATH` del shell y `.Renviron` no se carga con `--vanilla` | Facilita errores de arranque | Se documenta la ruta real de R y la ejecución normal con `shiny::runApp()`. |

## 6. Recomendaciones aplicadas en el rediseño

1. Separar UI, componentes y módulos en `R/` sin tocar la lógica de datos.
2. Centralizar la identidad visual en variables CSS y en `R/theme.R`.
3. Mantener las consultas SQL, la guardia `validar_sql()`, el rol `agente_ro` y la reactividad de 60 s.
4. No agregar dependencias: `bslib` + CSS + un JS pequeño cubren la experiencia.
5. Mostrar siempre fuente, fecha de reporte y antigüedad; no inventar variaciones ni tendencias.
6. Validar la app en un navegador real y documentar lo que no se pueda verificar.
