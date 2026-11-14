# FuelBot Lite · Identidad visual y tema (capa de presentación)
# Los colores viven también como variables CSS en www/motion.css.
FB <- list(
  version = "2.0.0",
  colores = c(
    forest   = "#26382E",
    deep     = "#405A3F",
    olive    = "#617A50",
    leaf     = "#91A77B",
    sage     = "#D9DED5",
    metal    = "#A6AAA3",
    mineral  = "#F7F8F5",
    white    = "#FFFFFF",
    graphite = "#26342B",
    muted    = "#5F6B63",
    line     = "#E3E7DF"
  ),
  estado = c(bajo = "#B4453C", medio = "#C58A2B", alto = "#4E7C46"),
  estado_lbl = c(bajo = "Bajo", medio = "Medio", alto = "Alto"),
  series = c("#405A3F", "#91A77B", "#617A50", "#C58A2B", "#A6AAA3")
)

fb_theme <- function() {
  bslib::bs_theme(
    version = 5,
    primary = unname(FB$colores[["deep"]]),
    secondary = unname(FB$colores[["olive"]]),
    success = unname(FB$estado[["alto"]]),
    info = unname(FB$colores[["leaf"]]),
    warning = "#C58A2B",
    danger = "#B4453C",
    bg = unname(FB$colores[["mineral"]]),
    fg = unname(FB$colores[["graphite"]]),
    base_font = "Manrope, Inter, system-ui, -apple-system, 'Segoe UI', sans-serif",
    heading_font = "Manrope, Inter, system-ui, -apple-system, 'Segoe UI', sans-serif"
  )
}

fb_fonts <- function() {
  tagList(
    tags$link(rel = "preconnect", href = "https://fonts.googleapis.com"),
    tags$link(rel = "preconnect", href = "https://fonts.gstatic.com", crossorigin = NA),
    tags$link(rel = "stylesheet",
              href = "https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&display=swap")
  )
}
