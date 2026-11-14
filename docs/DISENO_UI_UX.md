# Diseño UI/UX — FuelBot Lite 2.0

Documento de la fase 2 de `PROMP_MAESTRO.md`. Describe el sistema visual implementado en la aplicación real, no una propuesta teórica. Fecha: 2026-11-13.

## 1. Concepto

FuelBot Lite se presenta como una plataforma académica de **inteligencia energética territorial** para el departamento de La Paz. La interfaz combina una estética editorial sobria (verde profundo, salvia y blanco mineral) con lectura de datos densa pero ordenada. El objetivo es que una persona pueda responder tres preguntas sin ambigüedad:

1. ¿Qué reporta la ANH sobre saldos por estación y producto?
2. ¿Qué programó y despachó YPFB en el distrito comercial La Paz?
3. ¿Qué evidencia respalda cada cifra del agente?

La identidad evita el aspecto de panel administrativo genérico: encabezado editorial, navegación tipo píldora, tarjetas con acento lateral, tipografía Manrope y microinteracciones discretas.

## 2. Principios aplicados

- **Datos con contexto:** cada KPI incluye nota de alcance, fecha o conteo; cada módulo declara su fuente.
- **Separación semántica:** saldo reportado, programación y despacho confirmado nunca se suman ni se presentan como equivalentes.
- **Jerarquía antes que densidad:** máximo cuatro KPIs por fila, dos gráficos por sección, tablas con columnas secundarias ocultas en móvil.
- **Movimiento con propósito:** animaciones de entrada, pulso de datos vivos y estado de escritura del agente; no hay decoración animada permanente.
- **Consistencia:** una sola hoja activa (`www/motion.css`), variables CSS centralizadas y componentes R reutilizables.
- **Accesibilidad:** foco visible, etiquetas textuales además de color, y respeto a `prefers-reduced-motion`.

## 3. Paleta

Definida en `R/theme.R` (`FB$colores`) y en `:root` de `www/motion.css`. Cambiar estos valores actualiza la identidad completa.

| Token | HEX | Uso principal |
|---|---|---|
| Forest Green | `#26382E` | Barra de navegación, hero, KPI bosque, texto de máximo contraste |
| Deep Olive | `#405A3F` | Botón primario, enlaces, series de gráficos, bordes activos |
| Olive Green | `#617A50` | Acentos, iconos, foco, estados activos secundarios |
| Leaf Green | `#91A77B` | Píldora activa de navegación, acentos del hero, serie secundaria |
| Sage | `#D9DED5` | Fondos suaves, logo del footer, contraste sobre verde |
| Metallic Grey | `#A6AAA3` | Separadores, puntos de metadata, series neutras |
| Mineral White | `#F7F8F5` | Fondo general de la aplicación |
| Pure White | `#FFFFFF` | Tarjetas, tablas, compositor del chat |
| Graphite | `#26342B` | Texto principal, tooltips, bloques de SQL |

Colores de estado (no forman parte de la paleta de marca, pero son semánticos):

| Estado | HEX | Fondo de apoyo |
|---|---|---|
| Bajo | `#B4453C` | `#F9E7E4` |
| Medio | `#C58A2B` | `#FBF0D9` |
| Alto | `#4E7C46` | `#E7F0E2` |

Los estados se muestran siempre con texto («Bajo», «Medio», «Alto») además del color, para no depender solo de la percepción cromática.

## 4. Tipografía

- **Familia principal:** Manrope (Google Fonts, pesos 400–800), con respaldo en Inter, `system-ui`, `-apple-system`, `Segoe UI`, sans-serif.
- **Familia monoespaciada:** JetBrains Mono con respaldo en `ui-monospace`, `SFMono-Regular`, Consolas, para SQL y nombres de modelo.
- **Carga:** `fb_fonts()` en `R/theme.R`; si falla la red, la pila de respaldo mantiene la legibilidad.

| Rol | Tamaño | Peso | Detalle |
|---|---|---|---|
| Título del hero | `clamp(30px, 3.5vw, 46px)` | 800 | Interletrado −0.035em |
| Título de sección | `clamp(21px, 2.2vw, 27px)` | 800 | Interletrado −0.02em |
| Cuerpo | 14.5px | 400 | Interlineado 1.55 |
| Descripción de sección | 12.8px | 400 | Máximo 78 caracteres por línea |
| Título de tarjeta | 14.5px | 800 | Subtítulo de 11.5px |
| Valor KPI | `clamp(23px, 2.2vw, 30px)` | 800 | Cifras tabulares |
| Etiqueta KPI | 11.5px | 700 | Color gris verdoso |
| Tabla | 12.5px | 400 | Encabezados de 10.5px en mayúsculas |
| Chat | 13.2px | 400 | Burbujas con interlineado 1.58 |
| Metadata | 10.5–11px | 700–800 | Kickers, cuotas, notas legales |

## 5. Espaciado, radios y profundidad

- Contenedor máximo: **1480px**, con padding lateral fluido `clamp(14px, 2.6vw, 30px)`.
- Radios: **16px** para tarjetas, **10–12px** para controles, **999px** para píldoras.
- Sombras: dos niveles (`--fb-shadow`, `--fb-shadow-hover`), siempre suaves y de baja opacidad.
- Separación vertical: hero con margen 18px arriba y 10px abajo; secciones con 24px arriba y 14px abajo; rejillas con `gap: 1rem`.
- Rejilla de KPIs: cuatro columnas iguales en escritorio, dos en tablet, una en móvil (por el comportamiento de `layout_columns` y el ancho mínimo de las tarjetas).

## 6. Estructura visual

### 6.1 Navegación

- Barra fija (`position: sticky`) con degradado de verdes y sombra inferior.
- Marca con icono de hoja en un cuadrado translúcido.
- Cuatro destinos con icono: Resumen, Mapa, YPFB, Agente IA.
- Estado activo: píldora color hoja con texto oscuro y sombra; hover con fondo blanco translúcido.
- En móvil se colapsa en un botón hamburguesa y los enlaces ocupan el ancho completo.

### 6.2 Encabezado editorial

- Panel de 22px de radio con degradado verde, retícula tenue y arte SVG de anillos/energía (decorativo, `aria-hidden`).
- Contiene marca, versión, título «Inteligencia Energética», subtítulo, chips de fuentes y chip vivo «hace X h» calculado desde la última captura.
- En pantallas menores a 1100px el arte se oculta y el panel pasa a una columna.

### 6.3 Resumen

- Kicker + título + descripción y chip «Actualización automática».
- Cuatro KPIs: estaciones con datos, última captura ANH, porcentaje de pares con saldo bajo, litros despachados por YPFB el último día.
- Dos gráficos: barras horizontales apiladas por estado y producto; barras verticales apiladas de despachos por día con selector 7/14/30 días/todo.
- Bloque de notas metodológicas que separa explícitamente saldo, despacho y programación.

### 6.4 Mapa

- Barra de filtros (producto, estado, botón «Centrar mapa»).
- Cuatro estadísticas compactas: total, bajo, medio, alto.
- Mapa Leaflet con teselas OpenStreetMap, escala, marcadores circulares por estado, etiqueta con el nombre y popup con dirección, producto, saldo, fecha de reporte y antigüedad.
- Tabla sincronizada con los mismos filtros y nota de alcance.

### 6.5 YPFB

- Tres KPIs: programado pendiente, despachado confirmado y última fecha de datos.
- Tabla de programación pendiente con filtro por producto y formato de litros con separador de miles.
- Nota que aclara que programación no es despacho ni disponibilidad.

### 6.6 Agente IA

- Tarjeta de chat con avatar, nombre, modelo visible, estado (Listo / Procesando / Revisar error).
- Historial de conversación con burbujas diferenciadas, marca de tiempo y modelo usado.
- Evidencia SQL desplegable por respuesta, con número de consulta, filas devueltas, recorte a 50 y SQL en bloque oscuro.
- Compositor con placeholder, hint «Ctrl + Enter para enviar» y botón Enviar.
- Columna lateral: qué se puede consultar, preguntas de ejemplo, límites de seguridad y cuota de sesión (3/min, 30/sesión).
- Aviso legal sobre posibles errores del modelo.

### 6.7 Pie

- Grid de tres zonas: marca y propósito académico; fuentes, zona horaria y versión; estado de actualización por fuente.
- Sin instituciones, autores, patrocinadores ni certificaciones inventadas.

## 7. Componentes

| Componente | Implementación | Estados |
|---|---|---|
| KPI | `fb_kpi()` + `textOutput` | normal, hover elevado, dato faltante (`s/d`) |
| Chip | `fb_chip()` | neutro, vivo con pulso, sobre hero |
| Estadística compacta | `fb-stat()` | neutro, bajo, medio, alto, vacío |
| Tarjeta | `card()` + clases `fb-card` | normal, recalculando, vacío |
| Gráfico | Plotly con `FB$estado` y `FB$series` | con datos, mensaje vacío |
| Mapa | Leaflet + `leafletProxy` | con datos, sin coordenadas, filtro sin resultados |
| Tabla | DT con `fb_dt_lang()` | con datos, vacía, filtrada |
| Badge de estado | `fb_badge_estado()` | bajo, medio, alto, sin dato |
| Chat | `mod_agente.R` | vacío, escribiendo, respuesta, error, cuota agotada |
| SQL | `<details class="fb-sql">` | cerrado, abierto, error de consulta |
| Notificación | `showNotification` estilizada | advertencia de cuota |

## 8. Estados y mensajes

- **Vacío:** los gráficos muestran una anotación centrada («Sin reportes de saldo disponibles»); las tablas muestran encabezados y «Sin registros».
- **Cargando:** `.recalculating` atenúa la salida; el agente usa un indicador de tres puntos y un mensaje explícito; Shiny muestra barra de progreso con el número de consulta.
- **Error del agente:** burbuja con borde rojizo, estado «Revisar error» y mensaje sin exponer claves.
- **Cuota:** notificación de advertencia, indicador `n / 30` y barra de progreso.
- **Sin datos:** `s/d` o «sin registro» en lugar de valores inventados.
- **Dato vivo:** chip con punto pulsante y texto «hace X h»; si no hay registro, «sin registro».

## 9. Movimiento

- Duraciones: 120ms (micro), 200ms (base), 320ms (entrada).
- Curva: `cubic-bezier(.2, .8, .2, 1)`.
- Animaciones: `fb-rise` para KPIs y mensajes, `fb-fade` para pestañas y tarjetas, `fb-pulso` para el chip vivo y el estado ocupado, `fb-punto` para el indicador de escritura.
- Los KPIs entran escalonados (0, 50, 100, 150ms).
- `prefers-reduced-motion: reduce` desactiva animaciones, transiciones y desplazamiento suave.

## 10. Responsividad

| Breakpoint | Cambios |
|---|---|
| ≤1100px | Hero en una columna; se oculta el arte; footer en una columna |
| ≤820px | Secciones en columna; estadísticas del mapa en 2×2; chat más bajo; se ocultan columnas secundarias de tablas (dirección, reportado, antigüedad en mapa; fecha en YPFB) |
| ≤600px | Cuerpo a 14px; hero compacto; KPIs más densos; filtros en una columna; mapa a 420px; tarjetas y footer con menos padding |

Validación en 390×844: sin desplazamiento horizontal de página en Resumen, Mapa, YPFB y Agente; tabla YPFB de 308px con tres columnas visibles.

## 11. Accesibilidad

- Enlace de foco visible global (`:focus-visible`, contorno oliva de 2px).
- Iconos SVG decorativos con `aria-hidden="true"` y `focusable="false"`.
- El hero tiene `aria-label`; el arte es presentacional.
- Los estados usan texto además de color.
- Contraste: texto grafito sobre blanco mineral, blanco sobre verde profundo y texto oscuro sobre hoja; los textos auxiliares de 10.5–11px son metadata, no información crítica.
- Formularios con etiquetas visibles («Producto», «Estado del saldo», «Filtrar por producto»).
- El chat informa el estado con texto («Procesando…», «Listo»), no solo con el color del punto.
- Se respeta la preferencia de movimiento reducido.

## 12. Decisiones y concesiones

1. **Sin librerías visuales nuevas.** Se descartaron `shinyjs`, `shinyWidgets`, `fresh`, `echarts4r` y `bsicons`; bslib, CSS propio y un JS pequeño cubren la necesidad y reducen riesgo de instalación.
2. **OpenStreetMap en lugar de teselas con clave.** CartoDB requiere API key; OSM no, a costa de un estilo menos editorial. Se aplica un filtro CSS suave para integrarlo con la paleta.
3. **Manrope desde Google Fonts.** Mejora la identidad, pero requiere internet; la pila de respaldo evita bloquear la lectura.
4. **Gráfico de despachos con eje de fechas real.** Se personalizaron `tickvals`/`ticktext` para evitar etiquetas duplicadas y separadores anglosajones.
5. **Tabla móvil con columnas ocultas.** Prioriza producto, cliente y litros; la fecha queda disponible en escritorio. Es una concesión consciente para evitar scroll horizontal.
6. **Sin comparaciones históricas inventadas.** La cobertura de despachos confirmados es de un solo día; el gráfico lo refleja en lugar de simular una tendencia.

## 13. Evidencia visual

Capturas reales generadas con Chrome headless (1440px escritorio, 390px móvil) en `docs/capturas/`:

- `resumen.png`, `mapa.png` (con popup abierto), `ypfb.png`, `agente.png`, `agente_respuesta.png`.
- `resumen_movil.png`, `mapa_movil.png`, `ypfb_movil.png`, `agente_movil.png`.

Las capturas corresponden a datos reales capturados el 2026-11-13 a las 11:30 (hora Bolivia).
