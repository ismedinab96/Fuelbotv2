# FuelBot Lite · Módulo 3: programación y despachos de YPFB

mod_ypfb_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fb_section(
      "YPFB · Distrito comercial La Paz",
      "Programación y despachos",
      "Volúmenes planificados que aún no fueron atendidos y despachos confirmados desde planta. Son dos tipos de dato distintos y no deben sumarse entre sí."
    ),
    layout_columns(
      col_widths = c(4, 4, 4), gap = "1rem", fill = FALSE,
      fb_kpi(ns("kpi_prog"), "Programado pendiente", "documento", "oliva", ns("nota_prog")),
      fb_kpi(ns("kpi_desp"), "Despachado confirmado", "despacho", "bosque", ns("nota_desp")),
      fb_kpi(ns("kpi_fecha"), "Última fecha de datos", "reloj", "hoja", ns("nota_fecha"))
    ),
    card(
      class = "fb-card fb-table-card",
      card_header(fb_card_title(
        "Programación pendiente",
        "Registros no atendidos del último día con datos de YPFB",
        fb_chip("YPFB", "despacho")
      )),
      div(class = "fb-table-toolbar",
          selectInput(ns("producto"), "Filtrar por producto",
                      choices = c("Todos los productos" = "__todos__"), width = "280px")),
      DTOutput(ns("tabla_prog")),
      div(class = "fb-table-note",
          "La programación es un volumen planificado. No equivale a despacho confirmado ni a disponibilidad en la estación.")
    )
  )
}

mod_ypfb_server <- function(id, latido) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    prog <- reactive({
      latido()
      consultar("select producto, cliente, litros_programados, fecha_datos from fuel.v_ypfb_programacion where not atendida and fecha_datos = (select max(fecha_datos) from fuel.v_ypfb_programacion) order by litros_programados desc")
    })

    desp_dia <- reactive({
      latido()
      consultar("select max(fecha_despacho_efectivo) as fecha, sum(litros_despachados) as litros, count(*) as n from fuel.v_ypfb_despachos where despacho_confirmado and fecha_despacho_efectivo = (select max(fecha_despacho_efectivo) from fuel.v_ypfb_despachos where despacho_confirmado)")
    })

    output$kpi_prog <- renderText({
      d <- prog()
      if (is.null(d) || nrow(d) == 0) return("s/d")
      paste(fb_litros(sum(d$litros_programados, na.rm = TRUE)), "L")
    })
    output$nota_prog <- renderText({
      d <- prog()
      if (is.null(d) || nrow(d) == 0) return("sin registros pendientes")
      sprintf("%s registros · %d clientes",
              format(nrow(d), big.mark = ".", decimal.mark = ","), length(unique(d$cliente)))
    })

    output$kpi_desp <- renderText({
      d <- desp_dia()
      if (is.null(d) || nrow(d) == 0 || is.na(d$litros[1])) return("s/d")
      paste(fb_litros(d$litros[1]), "L")
    })
    output$nota_desp <- renderText({
      d <- desp_dia()
      if (is.null(d) || nrow(d) == 0 || is.na(d$litros[1])) return("sin despachos confirmados")
      sprintf("%s despachos · %s", format(d$n[1], big.mark = ".", decimal.mark = ","),
              format(as.Date(d$fecha[1]), "%d/%m/%Y"))
    })

    output$kpi_fecha <- renderText({
      d <- prog()
      if (is.null(d) || nrow(d) == 0) return("s/d")
      format(max(d$fecha_datos, na.rm = TRUE), "%d/%m/%Y")
    })
    output$nota_fecha <- renderText({
      d <- prog()
      if (is.null(d) || nrow(d) == 0) return("sin fecha disponible")
      "fecha de datos YPFB"
    })

    observeEvent(prog(), {
      d <- prog()
      ops <- if (is.null(d) || nrow(d) == 0) character() else sort(unique(d$producto))
      sel <- isolate(input$producto %||% "__todos__")
      if (!identical(sel, "__todos__") && !(sel %in% ops)) sel <- "__todos__"
      updateSelectInput(session, "producto",
                        choices = c("Todos los productos" = "__todos__",
                                    stats::setNames(ops, ops)),
                        selected = sel)
    })

    filtrada <- reactive({
      d <- prog()
      if (is.null(d) || nrow(d) == 0) return(NULL)
      sel <- input$producto %||% "__todos__"
      if (!identical(sel, "__todos__") && nzchar(sel)) d <- d[d$producto == sel, , drop = FALSE]
      d
    })

    output$tabla_prog <- renderDT({
      d <- filtrada()
      if (is.null(d) || nrow(d) == 0) {
        vacia <- data.frame(Producto = character(), Cliente = character(),
                            Litros = numeric(), Fecha = character(), stringsAsFactors = FALSE)
        return(datatable(vacia, rownames = FALSE,
                         colnames = c("Producto", "Cliente", "Litros", "Fecha de datos"),
                         options = list(pageLength = 10, language = fb_dt_lang(),
                                        searching = FALSE, paging = FALSE, info = FALSE)))
      }
      tab <- data.frame(
        Producto = d$producto,
        Cliente = d$cliente,
        Litros = as.numeric(d$litros_programados),
        Fecha = format(as.Date(d$fecha_datos), "%d/%m/%Y"),
        stringsAsFactors = FALSE
      )
      datatable(
        tab, rownames = FALSE, class = "display fb-dt",
        colnames = c("Producto", "Cliente", "Litros", "Fecha de datos"),
        options = list(
          pageLength = 10, lengthMenu = c(10, 25, 50, 100), autoWidth = FALSE,
          order = list(list(2, "desc")),
          columnDefs = list(
            list(className = "dt-right", targets = c(2, 3)),
            list(width = "120px", targets = 2),
            list(width = "130px", targets = 3)
          ),
          language = fb_dt_lang()
        )
      ) |>
        formatCurrency(columns = 3, currency = "", interval = 3, mark = ".", dec.mark = ",", digits = 0)
    })
  })
}
