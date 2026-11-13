# FuelBot Lite · Dashboard + agente (Shiny). Ejecutar con: shiny::runApp()  (desde la carpeta del proyecto)
# La app usa SOLO el rol de lectura (agente_ro): nunca puede modificar datos.
library(shiny); library(bslib); library(leaflet); library(plotly); library(DT)
source("pipeline/00_config.R", encoding = "UTF-8")
source("agente/agente_gemini.R", encoding = "UTF-8")

COLORES <- c(bajo = "#d64545", medio = "#e0a030", alto = "#2e9e5b")
consultar <- function(sql) {
  intento <- function() DBI::dbGetQuery(con_ro(), sql)
  tryCatch(intento(), error = function(e) { .fb$con <- NULL; tryCatch(intento(), error = function(e2) NULL) })
}
ahora_local <- function() as.POSIXct(format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = CFG$tz), tz = "UTC")

js <- "
$(document).on('click', '#enviar', function(){ $('#pensando').removeClass('hidden'); $('#enviar').prop('disabled', true); });
$(document).on('keydown', '#pregunta', function(e){ if (e.ctrlKey && e.key === 'Enter') { $('#enviar').click(); } });
Shiny.addCustomMessageHandler('fin', function(x){ $('#pensando').addClass('hidden'); $('#enviar').prop('disabled', false); window.scrollTo(0, document.body.scrollHeight); });
"

ui <- page_navbar(
  title = "FuelBot La Paz", theme = bs_theme(version = 5, primary = "#0f6e56"),
  header = tagList(tags$head(tags$link(rel = "stylesheet", href = "motion.css"), tags$script(HTML(js)))),
  nav_panel("Resumen",
    layout_columns(col_widths = c(3, 3, 3, 3), fill = FALSE,
      value_box("Estaciones con datos", textOutput("kpi_estaciones")),
      value_box("Última captura (ANH)", textOutput("kpi_captura")),
      value_box("Pares estación-producto con saldo «bajo»", textOutput("kpi_bajo")),
      value_box("Despachado YPFB (último día con datos)", textOutput("kpi_despacho"))),
    layout_columns(col_widths = c(6, 6),
      card(card_header("Estado de saldo por producto (último reporte)"), plotlyOutput("graf_estado")),
      card(card_header("Despachos YPFB confirmados por día (distrito La Paz)"), plotlyOutput("graf_ypfb"))),
    div(class = "aviso", "Fuentes: ANH (saldo reportado por estación) y YPFB (despachos y programación). Horas en hora de Bolivia. ",
        "«Saldo» es lo que reporta el surtidor: no garantiza que haya combustible disponible.")),
  nav_panel("Mapa",
    layout_sidebar(sidebar = sidebar(selectInput("producto", "Producto",
                      c("Gasolina Especial", "Di\u00e9sel Oil", "Gasolina Premium", "Di\u00e9sel ULS"))),
      leafletOutput("mapa", height = 560), DTOutput("tabla"))),
  nav_panel("YPFB", card(card_header("Programación pendiente (no atendida) del último día"), DTOutput("tabla_prog"))),
  nav_panel("Agente",
    div(class = "chat-wrap",
        uiOutput("chat"),
        div(id = "pensando", class = "typing hidden", span(), span(), span(), tags$em(" consultando la base…")),
        div(class = "chat-input",
            textAreaInput("pregunta", NULL, rows = 2, width = "100%",
                          placeholder = "Ej.: ¿Qué estaciones de El Alto reportan saldo alto de diésel? (Ctrl+Enter para enviar)"),
            actionButton("enviar", "Preguntar", class = "btn-primary")),
        div(class = "aviso", "El agente consulta solo datos de ANH/YPFB guardados en la base y puede equivocarse: revisa la evidencia y las consultas SQL."))))

server <- function(input, output, session) {
  # La interfaz se refresca solo cuando hay una captura nueva (revisa cada 60 s)
  latido <- reactivePoll(60000, session,
    checkFunc = function() { r <- consultar("select max(fecha_captura)::text m, count(*) n from fuel.v_saldo_actual"); if (is.null(r)) "" else paste(r$m, r$n) },
    valueFunc = function() Sys.time())
  saldo <- reactive({ latido(); consultar("select * from fuel.v_saldo_actual") })
  desp  <- reactive({ latido(); consultar("select fecha_despacho_efectivo as fecha, producto_general, sum(litros_despachados) litros from fuel.v_ypfb_despachos where despacho_confirmado group by 1,2 order by 1") })

  output$kpi_estaciones <- renderText({ d <- saldo(); req(d); format(length(unique(d$id_eess)), big.mark = ".") })
  output$kpi_captura <- renderText({ d <- saldo(); req(d, nrow(d) > 0)
    h <- as.numeric(difftime(ahora_local(), max(d$fecha_captura), units = "hours")); sprintf("hace %.1f h", h) })
  output$kpi_bajo <- renderText({ d <- saldo(); req(d, nrow(d) > 0); sprintf("%.0f %%", 100 * mean(d$saldo_estado == "bajo", na.rm = TRUE)) })
  output$kpi_despacho <- renderText({ d <- desp(); req(d, nrow(d) > 0)
    u <- max(d$fecha); sprintf("%s L (%s)", format(round(sum(d$litros[d$fecha == u])), big.mark = "."), format(u)) })

  output$graf_estado <- renderPlotly({ d <- saldo(); req(d, nrow(d) > 0)
    t <- as.data.frame(table(producto = d$producto, estado = factor(d$saldo_estado, c("bajo", "medio", "alto"))))
    plot_ly(t, x = ~producto, y = ~Freq, color = ~estado, colors = COLORES, type = "bar") |>
      layout(barmode = "stack", yaxis = list(title = "estaciones"), xaxis = list(title = ""), transition = list(duration = 300)) })
  output$graf_ypfb <- renderPlotly({ d <- desp(); req(d, nrow(d) > 0)
    plot_ly(d, x = ~fecha, y = ~litros, color = ~producto_general, type = "bar") |>
      layout(barmode = "stack", yaxis = list(title = "litros"), xaxis = list(title = ""), transition = list(duration = 300)) })

  datos_mapa <- reactive({ d <- saldo(); req(d); d[d$producto == input$producto & !is.na(d$lat) & !is.na(d$lng), ] })
  output$mapa <- renderLeaflet({ d <- datos_mapa(); req(nrow(d) > 0)
    popup <- sprintf("<b>%s</b><br>%s<br>Saldo: %s L (%s)<br>Reportado: %s<br><small>ANH · antig\u00fcedad %s h</small>",
                     htmltools::htmlEscape(d$nombre), htmltools::htmlEscape(d$direccion), format(d$saldo_litros, big.mark = "."),
                     d$saldo_estado, format(d$fecha_reporte), d$antiguedad_reporte_horas)
    leaflet(d) |> addTiles() |>
      addCircleMarkers(~lng, ~lat, radius = 7, stroke = TRUE, weight = 1, color = "#333", fillColor = unname(COLORES[d$saldo_estado]), fillOpacity = .9, popup = popup) |>
      addLegend("bottomright", colors = unname(COLORES), labels = names(COLORES), title = "Saldo reportado") })
  output$tabla <- renderDT({ d <- datos_mapa()
    datatable(d[, c("nombre", "saldo_litros", "saldo_estado", "fecha_reporte", "antiguedad_reporte_horas")],
              colnames = c("Estación", "Saldo (L)", "Estado", "Reportado", "Antigüedad (h)"), rownames = FALSE, options = list(pageLength = 8)) })

  output$tabla_prog <- renderDT({ latido()
    d <- consultar("select producto, cliente, litros_programados, fecha_datos from fuel.v_ypfb_programacion where not atendida and fecha_datos = (select max(fecha_datos) from fuel.v_ypfb_programacion) order by litros_programados desc")
    req(d); datatable(d, colnames = c("Producto", "Cliente", "Litros programados", "Fecha"), rownames = FALSE, options = list(pageLength = 10)) })

  # ── Chat con el agente ────────────────────────────────────────────────────
  chat <- reactiveVal(list()); uso <- reactiveValues(marcas = numeric(), total = 0)
  historial <- function(msgs) {   # solo texto de los últimos 3 turnos (ahorra cuota)
    msgs <- tail(msgs, 6); lapply(msgs, function(m) list(role = if (m$rol == "user") "user" else "model", parts = list(list(text = m$texto))))
  }
  observeEvent(input$enviar, {
    q <- trimws(input$pregunta)
    if (!nzchar(q)) { session$sendCustomMessage("fin", TRUE); return() }
    ahora <- as.numeric(Sys.time()); uso$marcas <- c(uso$marcas[uso$marcas > ahora - 60], ahora)
    if (length(uso$marcas) > 3 || uso$total >= 30) {
      showNotification("Demasiadas preguntas seguidas (límite para cuidar la cuota gratuita). Espera un minuto.", type = "warning")
      session$sendCustomMessage("fin", TRUE); return()
    }
    uso$total <- uso$total + 1
    res <- withProgress(message = "El agente está trabajando…", value = 0.1, {
      tryCatch(preguntar(q, historial(chat()), on_paso = function(n, sql, r)
                 setProgress(value = min(0.9, 0.1 + 0.2 * n), detail = paste0("Consulta ", n, if (!is.null(r$error)) " con error" else " ejecutada"))),
               error = function(e) list(respuesta = paste("No pude responder:", conditionMessage(e)), pasos = list()))
    })
    chat(c(chat(), list(list(rol = "user", texto = q), list(rol = "model", texto = res$respuesta, pasos = res$pasos))))
    updateTextAreaInput(session, "pregunta", value = "")
    session$sendCustomMessage("fin", TRUE)
  }, ignoreInit = TRUE)

  output$chat <- renderUI({
    msgs <- chat()
    if (!length(msgs)) return(div(class = "vacio", "Pregunta, por ejemplo: «¿Cuántas estaciones reportan saldo bajo de gasolina especial?» o «¿Cuánto despachó YPFB a La Paz esta semana?»"))
    tagList(lapply(msgs, function(m) {
      if (m$rol == "user") div(class = "msg msg-user", m$texto)
      else div(class = "msg msg-bot", HTML(shiny::markdown(htmltools::htmlEscape(m$texto))),
               if (length(m$pasos)) tags$details(tags$summary(sprintf("Consultas SQL ejecutadas (%d)", length(m$pasos))),
                                                 lapply(m$pasos, function(p) tags$pre(p$consulta))))
    }))
  })
  session$onSessionEnded(function() NULL)
}

shinyApp(ui, server)
