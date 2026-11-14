# FuelBot Lite · Dashboard + agente (Shiny). Ejecutar con: shiny::runApp()  (desde la carpeta del proyecto)
# La app usa SOLO el rol de lectura (agente_ro): nunca puede modificar datos.
library(shiny); library(bslib); library(leaflet); library(plotly); library(DT)

source("pipeline/00_config.R", encoding = "UTF-8")
source("agente/agente_gemini.R", encoding = "UTF-8")
for (archivo in c("R/theme.R", "R/components.R", "R/data.R", "R/mod_resumen.R",
                  "R/mod_mapa.R", "R/mod_ypfb.R", "R/mod_agente.R")) {
  source(archivo, encoding = "UTF-8")
}

ui <- page_navbar(
  title = div(class = "fb-brand",
              span(class = "fb-brand__mark", fb_icon("hoja", 18)),
              span(class = "fb-brand__name", "ChatBot FuelBot v1 DAT-253")),
  window_title = "ChatBot FuelBot v1 DAT-253",
  id = "nav_principal",
  theme = fb_theme(),
  navbar_options = navbar_options(
    bg = unname(FB$colores[["forest"]]),
    theme = "dark",
    collapsible = TRUE,
    underline = FALSE
  ),
  header = tagList(
    tags$head(
      fb_fonts(),
      tags$link(rel = "icon", type = "image/svg+xml",
                href = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='14' fill='%2326382E'/%3E%3Cpath d='M44 16c-14 1-24 7-24 18 0 5 3 9 8 9 10 0 16-11 16-27Z' fill='none' stroke='%23D9DED5' stroke-width='3'/%3E%3C/svg%3E"),
      tags$link(rel = "stylesheet", href = "motion.css?v=2.0.8"),
      tags$script(src = "custom.js?v=2.0.8")
    ),
    fb_hero_ui()
  ),
  footer = fb_footer_ui(),
  nav_panel("Resumen", icon = icon("chart-bar"), mod_resumen_ui("resumen")),
  nav_panel("Mapa", icon = icon("map-marker-alt"), mod_mapa_ui("mapa")),
  nav_panel("YPFB", icon = icon("truck"), mod_ypfb_ui("ypfb")),
  nav_panel("Agente IA", icon = icon("robot"), mod_agente_ui("agente")),
  fillable = FALSE
)

server <- function(input, output, session) {
  # La interfaz se refresca solo cuando hay una captura nueva (revisa cada 60 s)
  latido <- reactivePoll(60000, session,
    checkFunc = function() {
      r <- consultar("select max(fecha_captura)::text m, count(*) n from fuel.v_saldo_actual")
      if (is.null(r)) "" else paste(r$m, r$n)
    },
    valueFunc = function() Sys.time()
  )

  saldo <- reactive({ latido(); consultar("select * from fuel.v_saldo_actual") })
  desp <- reactive({
    latido()
    consultar("select fecha_despacho_efectivo as fecha, producto_general, sum(litros_despachados) litros from fuel.v_ypfb_despachos where despacho_confirmado group by 1,2 order by 1")
  })
  fuentes <- reactive({
    latido()
    consultar("select fuente, ultima_ingesta_ok from fuel.v_fuentes")
  })

  output$hero_meta <- renderUI({
    d <- saldo()
    chips <- list(
      fb_chip("ANH · saldos por estación", "base"),
      fb_chip("YPFB · despachos y programación", "despacho"),
      fb_chip("Bolivia UTC−4", "reloj")
    )
    if (!is.null(d) && nrow(d) > 0) {
      h <- fb_horas_captura(max(d$fecha_captura, na.rm = TRUE))
      chips <- c(chips, list(fb_chip(fb_hace(h), "rayo", "is-live")))
    }
    div(class = "fb-hero__chips", chips)
  })

  output$pie_estado <- renderText({
    f <- fuentes()
    if (is.null(f) || nrow(f) == 0) return("Actualización: sin registro disponible")
    texto <- vapply(seq_len(nrow(f)), function(i) {
      x <- f$ultima_ingesta_ok[i]
      h <- if (inherits(x, "POSIXt") && !is.na(x)) fb_horas_utc(x) else NA_real_
      sprintf("%s: %s", f$fuente[i], fb_hace(h))
    }, character(1))
    paste("Actualización —", paste(texto, collapse = " · "))
  })

  mod_resumen_server("resumen", saldo, desp)
  mod_mapa_server("mapa", saldo)
  mod_ypfb_server("ypfb", latido)
  mod_agente_server("agente")
}

shinyApp(ui, server)
