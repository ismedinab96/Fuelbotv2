# FuelBot Lite · Módulo 1: resumen ejecutivo

mod_resumen_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fb_section(
      "Resumen ejecutivo",
      "Panorama de disponibilidad reportada",
      "Indicadores calculados sobre el último reporte disponible por estación y producto. La aplicación revisa si hay una captura nueva cada 60 segundos.",
      derecha = fb_chip("Actualización automática", "reloj")
    ),
    layout_columns(
      col_widths = c(3, 3, 3, 3), gap = "1rem", fill = FALSE,
      fb_kpi(ns("kpi_estaciones"), "Estaciones con datos", "estacion", "oliva", ns("nota_estaciones")),
      fb_kpi(ns("kpi_captura"), "Última captura ANH", "reloj", "hoja", ns("nota_captura")),
      fb_kpi(ns("kpi_bajo"), "Pares con saldo «bajo»", "alerta", "ambar", ns("nota_bajo")),
      fb_kpi(ns("kpi_despacho"), "Despachado por YPFB", "despacho", "bosque", ns("nota_despacho"))
    ),
    layout_columns(
      col_widths = c(6, 6), gap = "1rem", fill = FALSE,
      card(
        class = "fb-card fb-chart-card",
        card_header(fb_card_title(
          "Estado de saldo por producto",
          "Último reporte ANH por estación · número de estaciones",
          fb_chip("ANH", "base")
        )),
        plotlyOutput(ns("graf_estado"), height = "330px")
      ),
      card(
        class = "fb-card fb-chart-card",
        card_header(fb_card_title(
          "Despachos confirmados de YPFB",
          "Litros por día y producto · distrito comercial La Paz",
          selectInput(ns("rango"), NULL,
                      choices = c("7 días" = 7, "14 días" = 14, "30 días" = 30, "Todo" = 0),
                      selected = 14, width = "132px")
        )),
        plotlyOutput(ns("graf_ypfb"), height = "330px")
      )
    ),
    tags$section(
      class = "fb-notes",
      h3(fb_icon("lista", 17), "Notas metodológicas"),
      tags$ul(
        tags$li(HTML("<strong>Saldo reportado (ANH):</strong> inventario que declara cada estación de servicio. No equivale a disponibilidad ni a venta al público.")),
        tags$li(HTML("<strong>Despacho confirmado (YPFB):</strong> cisterna que salió de planta hacia el distrito comercial. No implica que el producto esté disponible en una estación.")),
        tags$li(HTML("<strong>Programación (YPFB):</strong> volumen planificado que puede no haberse atendido; se analiza por separado en la pestaña YPFB.")),
        tags$li(HTML("Cada registro conserva fecha de reporte y fecha de captura. Fechas y horas en hora de Bolivia (UTC−4). Los estados bajo, medio y alto son los reportados por ANH; sus umbrales no se exponen en la fuente."))
      )
    )
  )
}

mod_resumen_server <- function(id, saldo, desp) {
  moduleServer(id, function(input, output, session) {
    output$kpi_estaciones <- renderText({
      d <- saldo()
      if (is.null(d) || nrow(d) == 0) return("s/d")
      format(length(unique(d$id_eess)), big.mark = ".", decimal.mark = ",")
    })
    output$nota_estaciones <- renderText({
      d <- saldo()
      if (is.null(d) || nrow(d) == 0) return("sin datos")
      sprintf("%d productos monitoreados", length(unique(d$producto)))
    })

    output$kpi_captura <- renderText({
      d <- saldo()
      if (is.null(d) || nrow(d) == 0) return("s/d")
      fb_hace(fb_horas_captura(max(d$fecha_captura, na.rm = TRUE)))
    })
    output$nota_captura <- renderText({
      d <- saldo()
      if (is.null(d) || nrow(d) == 0) return("sin datos")
      paste("captura", format(max(d$fecha_captura, na.rm = TRUE), "%d/%m/%Y %H:%M"))
    })

    output$kpi_bajo <- renderText({
      d <- saldo()
      if (is.null(d) || nrow(d) == 0) return("s/d")
      sprintf("%.0f %%", 100 * mean(d$saldo_estado == "bajo", na.rm = TRUE))
    })
    output$nota_bajo <- renderText({
      d <- saldo()
      if (is.null(d) || nrow(d) == 0) return("sin datos")
      sprintf("de %s pares estación-producto", format(nrow(d), big.mark = ".", decimal.mark = ","))
    })

    output$kpi_despacho <- renderText({
      d <- desp()
      if (is.null(d) || nrow(d) == 0) return("s/d")
      u <- max(d$fecha, na.rm = TRUE)
      paste(fb_litros(sum(d$litros[d$fecha == u], na.rm = TRUE)), "L")
    })
    output$nota_despacho <- renderText({
      d <- desp()
      if (is.null(d) || nrow(d) == 0) return("sin datos")
      paste("confirmado el", format(max(d$fecha, na.rm = TRUE), "%d/%m/%Y"))
    })

    output$graf_estado <- renderPlotly({
      d <- saldo()
      if (is.null(d) || nrow(d) == 0) return(fb_plot_vacio("Sin reportes de saldo disponibles"))
      d$producto <- factor(d$producto, levels = unname(CFG$productos))
      d$estado <- factor(as.character(d$saldo_estado), levels = c("bajo", "medio", "alto"))
      t <- as.data.frame(table(producto = d$producto, estado = d$estado, useNA = "no"))
      names(t) <- c("producto", "estado", "n")
      t$estado_lbl <- factor(unname(FB$estado_lbl[as.character(t$estado)]),
                             levels = unname(FB$estado_lbl))
      plot_ly(t, x = ~n, y = ~producto, color = ~estado_lbl,
              colors = unname(FB$estado), type = "bar", orientation = "h",
              hovertemplate = "%{y}<br>%{fullData.name}: %{x} estaciones<extra></extra>",
              marker = list(line = list(color = "#FFFFFF", width = 1))) |>
        layout(
          barmode = "stack", bargap = .38,
          font = list(family = "Manrope, Inter, sans-serif", color = unname(FB$colores[["graphite"]]), size = 11.5),
          paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
          margin = list(l = 6, r = 14, t = 8, b = 6),
          legend = list(orientation = "h", x = 0, y = 1.1, xanchor = "left", yanchor = "bottom",
                        font = list(size = 11), title = list(text = "")),
          xaxis = list(title = list(text = "estaciones", font = list(size = 11)),
                       gridcolor = "#E9EDE4", zeroline = FALSE, tickfont = list(size = 11)),
          yaxis = list(title = "", tickfont = list(size = 11.5),
                       categoryorder = "array", categoryarray = rev(levels(t$producto))),
          hoverlabel = list(bgcolor = "#26342B", font = list(color = "#F7F8F5", size = 11.5))
        ) |>
        config(displayModeBar = FALSE)
    })

    output$graf_ypfb <- renderPlotly({
      d <- desp()
      if (is.null(d) || nrow(d) == 0) return(fb_plot_vacio("Sin despachos confirmados disponibles"))
      d$fecha <- as.Date(d$fecha)
      rango <- suppressWarnings(as.integer(input$rango))
      if (is.na(rango)) rango <- 14
      if (rango > 0) d <- d[d$fecha >= max(d$fecha, na.rm = TRUE) - (rango - 1), , drop = FALSE]
      d$producto_general <- factor(d$producto_general, levels = sort(unique(d$producto_general)))
      d$litros_txt <- paste0(fb_litros(d$litros), " L")
      tope <- max(tapply(d$litros, d$fecha, sum, na.rm = TRUE), na.rm = TRUE)
      paso <- 1000
      for (p in c(1000, 2000, 5000, 10000, 20000, 50000, 100000,
                  200000, 500000, 1000000, 2000000)) {
        if (p >= tope / 4) { paso <- p; break }
      }
      marcas <- seq(0, ceiling(tope / paso) * paso, by = paso)
      dias <- as.numeric(diff(range(d$fecha))) + 1
      paso_dias <- if (dias <= 12) 1 else if (dias <= 24) 2 else 5
      rango_x <- range(d$fecha)
      marcas_x <- sort(unique(d$fecha))
      marcas_x <- marcas_x[seq(1, length(marcas_x), by = paso_dias)]
      plot_ly(data = d) |>
        add_bars(x = ~fecha, y = ~litros, color = ~producto_general, colors = FB$series,
                 customdata = ~litros_txt, width = .55 * 86400000,
                 hovertemplate = "%{x|%d/%m/%Y}<br>%{fullData.name}: %{customdata}<extra></extra>",
                 marker = list(line = list(color = "#FFFFFF", width = .6))) |>
        layout(
          barmode = "stack", bargap = .32,
          font = list(family = "Manrope, Inter, sans-serif", color = unname(FB$colores[["graphite"]]), size = 11.5),
          paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
          margin = list(l = 6, r = 14, t = 8, b = 6),
          legend = list(orientation = "h", x = 0, y = 1.1, xanchor = "left", yanchor = "bottom",
                        font = list(size = 11), title = list(text = "")),
          xaxis = list(title = "", type = "date", tickformat = "%d/%m",
                       tickmode = "array", tickvals = marcas_x,
                       ticktext = format(marcas_x, "%d/%m"),
                       range = c(rango_x[1] - 1, rango_x[2] + 1),
                       gridcolor = "#E9EDE4", zeroline = FALSE,
                       tickfont = list(size = 10.5), hoverformat = "%d/%m/%Y"),
          yaxis = list(title = list(text = "litros", font = list(size = 11)),
                       gridcolor = "#E9EDE4", zeroline = FALSE,
                       tickmode = "array", tickvals = marcas,
                       ticktext = format(marcas, big.mark = ".", decimal.mark = ",",
                                         scientific = FALSE, trim = TRUE),
                       range = c(0, max(marcas)), tickfont = list(size = 10.5)),
          separators = ",.",
          hoverlabel = list(bgcolor = "#26342B", font = list(color = "#F7F8F5", size = 11.5))
        ) |>
        config(displayModeBar = FALSE)
    })
  })
}
