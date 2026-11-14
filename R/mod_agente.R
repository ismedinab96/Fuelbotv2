# FuelBot Lite · Módulo 4: agente conversacional Gemini

mod_agente_ui <- function(id) {
  ns <- NS(id)
  tagList(
    fb_section(
      "Asistente analítico",
      "Agente FuelBot AI",
      "Consultas en lenguaje natural sobre las vistas de ANH y YPFB. El agente trabaja con SQL de solo lectura y muestra la evidencia de cada respuesta."
    ),
    layout_columns(
      col_widths = c(8, 4), gap = "1rem", fill = FALSE,
      card(
        class = "fb-card fb-chat",
        div(class = "fb-chat__head",
            div(class = "fb-chat__avatar", fb_icon("bot", 22)),
            div(class = "fb-chat__id",
                h2("FuelBot AI"),
                div(class = "fb-chat__sub", uiOutput(ns("modelo"), inline = TRUE))),
            uiOutput(ns("estado"), inline = TRUE)),
        div(class = "fb-chat__scroll",
            uiOutput(ns("chat")),
            div(id = ns("pensando"), class = "typing hidden",
                span(), span(), span(),
                tags$em("consulta la base y redacta la respuesta…"))),
        div(class = "fb-chat__composer",
            textAreaInput(ns("pregunta"), NULL, rows = 2, width = "100%",
                          placeholder = "Ej.: ¿Qué estaciones de El Alto reportan saldo alto de diésel?"),
            div(class = "fb-chat__actions",
                span(class = "fb-hint", "Ctrl + Enter para enviar"),
                actionButton(ns("enviar"), tagList(fb_icon("enviar", 16), "Enviar"),
                             class = "btn btn-primary fb-send"))),
        div(class = "fb-chat__legal",
            "El agente puede equivocarse. Revisa la fuente, las fechas y las consultas SQL desplegables antes de usar una cifra.")
      ),
      div(class = "fb-chat-side",
          div(class = "fb-side-card",
              h3("Qué puedes consultar"),
              tags$ul(class = "fb-side-list",
                      tags$li(fb_icon("estacion", 15), span("Saldos reportados por estación y producto (ANH).")),
                      tags$li(fb_icon("despacho", 15), span("Despachos confirmados y programación (YPFB).")),
                      tags$li(fb_icon("base", 15), span("Cobertura temporal y fuentes registradas.")),
                      tags$li(fb_icon("grafico", 15), span("Conteos, promedios y comparaciones con evidencia SQL."))),
              div(class = "fb-ejemplos",
                  actionButton(ns("ej1"), "¿Cuántas estaciones reportan saldo alto de gasolina especial?",
                               class = "fb-ejemplo"),
                  actionButton(ns("ej2"), "¿Qué estaciones de El Alto reportan saldo bajo de diésel?",
                               class = "fb-ejemplo"),
                  actionButton(ns("ej3"), "¿Cuántos litros despachó YPFB el último día?",
                               class = "fb-ejemplo"))),
          div(class = "fb-side-card",
              h3("Límites y seguridad"),
              tags$ul(class = "fb-side-list",
                      tags$li(fb_icon("escudo", 15), span("Solo lectura: el rol de base de datos no puede modificar información.")),
                      tags$li(fb_icon("base", 15), span("Máximo 50 filas por consulta y 6 pasos por pregunta.")),
                      tags$li(fb_icon("alerta", 15), span("Un saldo reportado no garantiza disponibilidad física de combustible.")),
                      tags$li(fb_icon("reloj", 15), span("Fechas y horas en hora de Bolivia (UTC−4).")))),
          div(class = "fb-side-card", uiOutput(ns("cuota")))
      )
    )
  )
}

mod_agente_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    chat <- reactiveVal(list())
    uso <- reactiveValues(marcas = numeric(), total = 0)
    estado <- reactiveVal("listo")
    modelo <- reactiveVal(Sys.getenv("GEMINI_MODEL", ""))

    historial <- function(msgs) {
      msgs <- tail(msgs, 6)
      lapply(msgs, function(m) {
        list(role = if (m$rol == "user") "user" else "model",
             parts = list(list(text = m$texto)))
      })
    }

    output$modelo <- renderText({
      m <- modelo()
      if (nzchar(m)) paste("Gemini ·", m) else "Gemini · selección automática"
    })

    output$estado <- renderUI({
      e <- estado()
      cls <- switch(e, procesando = "is-busy", error = "is-error", "is-ready")
      lbl <- switch(e, procesando = "Procesando…", error = "Revisar error", "Listo")
      span(class = paste("fb-status", cls), span(class = "fb-status__dot"), lbl)
    })

    output$cuota <- renderUI({
      pct <- min(100, round(100 * uso$total / 30))
      div(class = "fb-quota",
          div(class = "fb-quota__top",
              span("Consultas en esta sesión"),
              strong(sprintf("%d / 30", uso$total))),
          div(class = "fb-quota__bar",
              div(class = "fb-quota__fill", style = sprintf("width:%d%%", pct))),
          p(class = "fb-quota__hint", "Máximo 3 preguntas por minuto."))
    })

    rellenar <- function(texto) {
      updateTextAreaInput(session, "pregunta", value = texto)
    }
    observeEvent(input$ej1, rellenar("¿Cuántas estaciones reportan saldo alto de gasolina especial?"), ignoreInit = TRUE)
    observeEvent(input$ej2, rellenar("¿Qué estaciones de El Alto reportan saldo bajo de diésel?"), ignoreInit = TRUE)
    observeEvent(input$ej3, rellenar("¿Cuántos litros despachó YPFB el último día?"), ignoreInit = TRUE)

    observeEvent(input$enviar, {
      q <- trimws(input$pregunta)
      if (!nzchar(q)) {
        session$sendCustomMessage("fb_fin", TRUE)
        return()
      }

      ahora <- as.numeric(Sys.time())
      uso$marcas <- c(uso$marcas[uso$marcas > ahora - 60], ahora)
      if (length(uso$marcas) > 3 || uso$total >= 30) {
        showNotification(
          "Límite de cuota: máximo 3 preguntas por minuto y 30 por sesión. Espera un momento.",
          type = "warning", duration = 6
        )
        session$sendCustomMessage("fb_fin", TRUE)
        return()
      }
      uso$total <- uso$total + 1
      estado("procesando")

      res <- withProgress(message = "El agente está trabajando…", value = 0.1, {
        tryCatch(
          preguntar(q, historial(chat()), on_paso = function(n, sql, r) {
            setProgress(value = min(0.9, 0.1 + 0.2 * n),
                        detail = paste0("Consulta ", n,
                                        if (!is.null(r$error)) " con error" else " ejecutada"))
          }),
          error = function(e) {
            list(respuesta = paste("No pude responder:", conditionMessage(e)),
                 pasos = list(), modelo = "", error = TRUE)
          }
        )
      })

      hora <- format(Sys.time(), "%H:%M", tz = CFG$tz)
      chat(c(
        chat(),
        list(list(rol = "user", texto = q, hora = hora)),
        list(list(rol = "model", texto = res$respuesta %||% "Sin respuesta.",
                  pasos = res$pasos %||% list(), hora = hora,
                  modelo = res$modelo %||% "", error = isTRUE(res$error)))
      ))
      if (nzchar(res$modelo %||% "")) modelo(res$modelo)
      estado(if (isTRUE(res$error)) "error" else "listo")
      updateTextAreaInput(session, "pregunta", value = "")
      session$sendCustomMessage("fb_fin", TRUE)
      session$sendCustomMessage("fb_scroll", TRUE)
    }, ignoreInit = TRUE)

    output$chat <- renderUI({
      msgs <- chat()
      if (!length(msgs)) {
        return(div(class = "fb-chat__empty",
                   div(class = "fb-chat__empty-icon", fb_icon("bot", 26)),
                   h3("Pregunta sobre los datos registrados"),
                   p("El asistente consulta las vistas de ANH y YPFB en modo solo lectura. Cada respuesta incluye fuente y fechas, y las consultas SQL quedan disponibles como evidencia.")))
      }
      tagList(lapply(msgs, function(m) {
        if (m$rol == "user") {
          div(class = "fb-msg fb-msg--user",
              div(class = "fb-msg__content",
                  div(class = "fb-msg__meta", span("Tú"), span(m$hora)),
                  div(class = "fb-msg__bubble", m$texto)))
        } else {
          pasos <- m$pasos
          div(class = "fb-msg fb-msg--bot",
              div(class = "fb-msg__avatar", fb_icon("bot", 17)),
              div(class = "fb-msg__content",
                  div(class = "fb-msg__meta",
                      span("FuelBot AI"), span(m$hora),
                      if (nzchar(m$modelo)) span(class = "fb-msg__model", m$modelo)),
                  div(class = paste("fb-msg__bubble", if (isTRUE(m$error)) "is-error"),
                      HTML(shiny::markdown(htmltools::htmlEscape(m$texto)))),
                  if (length(pasos)) {
                    tags$details(
                      class = "fb-sql",
                      tags$summary(fb_icon("base", 14),
                                   sprintf("Consultas SQL ejecutadas (%d)", length(pasos))),
                      lapply(seq_along(pasos), function(i) {
                        p <- pasos[[i]]
                        r <- p$resultado
                        err <- !is.null(r$error)
                        resumen <- if (err) "error" else {
                          paste0(length(r$filas), " filas", if (isTRUE(r$recortado)) " · recortado a 50" else "")
                        }
                        div(class = "fb-sql__step",
                            div(class = "fb-sql__head",
                                span(class = "fb-sql__n", paste0("Consulta ", i)),
                                span(class = paste("fb-sql__res", if (err) "is-error"),
                                     resumen)),
                            tags$pre(class = "fb-sql__code", p$consulta),
                            if (err) div(class = "fb-sql__error", r$error))
                      })
                    )
                  })
          )
        }
      }))
    })
  })
}
