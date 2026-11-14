# FuelBot Lite · Módulo 2: mapa territorial y tabla sincronizada

mod_mapa_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fb_section(
      "Mapa territorial",
      "Disponibilidad reportada por estación",
      "Explora las estaciones del departamento de La Paz. El filtro actualiza el mapa y la tabla; los popups muestran solo campos registrados por ANH."
    ),
    card(
      class = "fb-card fb-filterbar",
      div(class = "fb-filters",
          div(class = "fb-field",
              selectInput(ns("producto"), "Producto", choices = unname(CFG$productos),
                          selected = "Gasolina Especial", width = "100%")),
          div(class = "fb-field",
              selectInput(ns("estado"), "Estado del saldo",
                          choices = c("Todos" = "todos", "Bajo" = "bajo",
                                      "Medio" = "medio", "Alto" = "alto"),
                          width = "100%")),
          div(class = "fb-field fb-field--action",
              actionButton(ns("centrar"), tagList(fb_icon("mapa", 16), "Centrar mapa"),
                           class = "btn btn-outline-secondary fb-center")))
    ),
    div(class = "fb-stats", uiOutput(ns("stats"))),
    card(
      class = "fb-card fb-map-card",
      div(class = "fb-map", leafletOutput(ns("mapa"), height = "560px"))
    ),
    card(
      class = "fb-card fb-table-card",
      card_header(fb_card_title(
        "Estaciones visibles",
        "Tabla sincronizada con el producto y el estado seleccionados",
        fb_chip("ANH", "base")
      )),
      DTOutput(ns("tabla")),
      div(class = "fb-table-note",
          "Saldo reportado por la estación según ANH. Un saldo bajo no confirma desabastecimiento y un saldo alto no garantiza venta al público.")
    )
  )
}

mod_mapa_server <- function(id, saldo) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    limites <- function(d) {
      list(lng = range(d$lng, na.rm = TRUE), lat = range(d$lat, na.rm = TRUE))
    }
    encuadrar <- function(m, d) {
      b <- limites(d)
      fitBounds(m, b$lng[1], b$lat[1], b$lng[2], b$lat[2],
                options = list(padding = c(24, 24)))
    }

    base <- reactive({
      d <- saldo()
      if (is.null(d) || nrow(d) == 0) return(NULL)
      d <- d[d$producto == input$producto & !is.na(d$lat) & !is.na(d$lng), , drop = FALSE]
      d
    })

    datos <- reactive({
      d <- base()
      if (is.null(d) || nrow(d) == 0) return(d)
      if (!identical(input$estado, "todos")) {
        d <- d[as.character(d$saldo_estado) == input$estado, , drop = FALSE]
      }
      d
    })

    agregar_marcadores <- function(m, d) {
      col <- unname(FB$estado[as.character(d$saldo_estado)])
      col[is.na(col)] <- unname(FB$colores[["metal"]])
      m |>
        addCircleMarkers(
          data = d, lng = ~lng, lat = ~lat,
          radius = 7, stroke = TRUE, color = "#FFFFFF", weight = 2, opacity = 1,
          fillColor = col, fillOpacity = .92,
          popup = fb_popup(d),
          popupOptions = popupOptions(maxWidth = 330, closeButton = TRUE,
                                      autoPanPadding = c(24, 24)),
          label = ~nombre,
          labelOptions = labelOptions(direction = "auto", textsize = "12px", opacity = .92)
        ) |>
        addLegend(
          position = "bottomright", layerId = "fb_legenda",
          colors = unname(FB$estado), labels = unname(FB$estado_lbl),
          title = "Saldo reportado · ANH", opacity = .95
        )
    }

    output$stats <- renderUI({
      d <- base()
      if (is.null(d) || nrow(d) == 0) {
        return(div(class = "fb-stats__empty", "Sin estaciones con coordenadas para este producto."))
      }
      est <- as.character(d$saldo_estado)
      stat <- function(etiqueta, valor, tono) {
        div(class = paste("fb-stat", paste0("fb-stat--", tono)),
            span(class = "fb-stat__label", etiqueta),
            strong(class = "fb-stat__value", valor))
      }
      tagList(
        stat("Estaciones", nrow(d), "neutro"),
        stat("Bajo", sum(est == "bajo", na.rm = TRUE), "bajo"),
        stat("Medio", sum(est == "medio", na.rm = TRUE), "medio"),
        stat("Alto", sum(est == "alto", na.rm = TRUE), "alto")
      )    })

    output$mapa <- renderLeaflet({
      d <- isolate(datos())
      m <- leaflet() |>
        addProviderTiles(providers$OpenStreetMap, group = "osm") |>
        addScaleBar(position = "bottomleft")
      if (is.null(d) || nrow(d) == 0) {
        m <- m |> setView(-68.15, -16.5, 9)
      } else {
        m <- encuadrar(m, d) |>
          agregar_marcadores(d)
      }
      m
    })

    observeEvent(datos(), {
      d <- datos()
      proxy <- leafletProxy(ns("mapa"))
      proxy <- proxy |> clearMarkers() |> removeControl("fb_legenda")
      if (!is.null(d) && nrow(d) > 0) proxy <- agregar_marcadores(proxy, d)
    }, ignoreInit = TRUE)

    observeEvent(input$producto, {
      d <- datos()
      if (!is.null(d) && nrow(d) > 0) {
        encuadrar(leafletProxy(ns("mapa")), d)
      }
    }, ignoreInit = TRUE)

    observeEvent(input$centrar, {
      d <- datos()
      if (!is.null(d) && nrow(d) > 0) {
        encuadrar(leafletProxy(ns("mapa")), d)
      } else {
        leafletProxy(ns("mapa")) |> setView(-68.15, -16.5, 9)
      }
    })

    output$tabla <- renderDT({
      d <- datos()
      if (is.null(d) || nrow(d) == 0) {
        vacia <- data.frame(Estacion = character(), Direccion = character(), Saldo = numeric(),
                            Estado = character(), Reportado = character(), Antiguedad = numeric(),
                            stringsAsFactors = FALSE)
        return(datatable(vacia, rownames = FALSE, colnames = c("Estación", "Dirección", "Saldo (L)",
                                                              "Estado", "Reportado", "Antigüedad (h)"),
                         options = list(pageLength = 8, language = fb_dt_lang(),
                                        searching = FALSE, paging = FALSE, info = FALSE)))
      }
      tab <- data.frame(
        Estacion = htmltools::htmlEscape(d$nombre),
        Direccion = htmltools::htmlEscape(d$direccion),
        Saldo = as.numeric(d$saldo_litros),
        Estado = fb_badge_estado(d$saldo_estado),
        Reportado = format(d$fecha_reporte, "%Y-%m-%d %H:%M"),
        Antiguedad = as.numeric(d$antiguedad_reporte_horas),
        stringsAsFactors = FALSE
      )
      datatable(
        tab, escape = FALSE, rownames = FALSE, class = "display fb-dt",
        colnames = c("Estación", "Dirección", "Saldo (L)", "Estado", "Reportado", "Antigüedad (h)"),
        options = list(
          pageLength = 8, lengthMenu = c(8, 15, 25, 50), autoWidth = FALSE,
          order = list(list(2, "desc")),
          columnDefs = list(list(className = "dt-right", targets = c(2, 5))),
          language = fb_dt_lang()
        )
      ) |>
        formatCurrency(columns = 3, currency = "", interval = 3, mark = ".", dec.mark = ",", digits = 0) |>
        formatRound(columns = 6, digits = 1, dec.mark = ",")
    })
  })
}
