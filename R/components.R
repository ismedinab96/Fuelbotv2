# FuelBot Lite · Componentes de interfaz reutilizables (sin dependencias nuevas)

fb_icon <- function(nombre, tamano = 20, clase = NULL) {
  trazo <- switch(
    nombre,
    estacion = '<path d="M4 21V8l8-5 8 5v13"/><path d="M3 21h18"/><path d="M9 21v-7h6v7"/><path d="M12 8v3"/>',
    reloj = '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    alerta = '<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
    despacho = '<path d="M3 6h11v10H3z"/><path d="M14 9h4l3 3v4h-7z"/><circle cx="7" cy="18" r="2"/><circle cx="17" cy="18" r="2"/>',
    mapa = '<path d="M21 10c0 7-9 12-9 12S3 17 3 10a9 9 0 0 1 18 0Z"/><circle cx="12" cy="10" r="3"/>',
    documento = '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><path d="M14 2v6h6"/><path d="M9 13h6M9 17h6"/>',
    bot = '<rect x="4" y="7" width="16" height="12" rx="3"/><path d="M12 7V4"/><circle cx="12" cy="3" r="1.2"/><path d="M9 12h.01M15 12h.01"/><path d="M9 16h6"/>',
    usuario = '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    base = '<ellipse cx="12" cy="5" rx="8" ry="3"/><path d="M4 5v14c0 1.7 3.6 3 8 3s8-1.3 8-3V5"/><path d="M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3"/>',
    escudo = '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/>',
    hoja = '<path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.5 19 2c1 2 2 4.2 2 8 0 5.5-4.8 10-10 10Z"/><path d="M2 21c0-3 1.9-5.4 5.1-6"/>',
    rayo = '<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8Z"/>',
    lista = '<path d="M8 6h13M8 12h13M8 18h13"/><path d="M3 6h.01M3 12h.01M3 18h.01"/>',
    enviar = '<path d="M22 2 11 13"/><path d="M22 2 15 22l-4-9-9-4Z"/>',
    grafico = '<path d="M3 3v18h18"/><path d="M7 15l4-4 3 3 5-6"/>',
    check = '<path d="m20 6-11 11-5-5"/>',
    '<circle cx="12" cy="12" r="9"/>'
  )
  cls <- if (is.null(clase)) "fb-ico" else paste("fb-ico", clase)
  htmltools::HTML(sprintf(
    '<svg class="%s" width="%s" height="%s" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">%s</svg>',
    cls, tamano, tamano, trazo))
}

fb_dec <- function(x, digitos = 1) {
  ifelse(is.na(x), "s/d",
         formatC(as.numeric(x), format = "f", digits = digitos, decimal.mark = ",", big.mark = "."))
}

fb_litros <- function(x) {
  ifelse(is.na(x), "s/d",
         format(round(as.numeric(x)), big.mark = ".", decimal.mark = ",",
                scientific = FALSE, trim = TRUE))
}

fb_hace <- function(horas) {
  ifelse(is.na(horas), "sin registro",
         ifelse(horas < 1, "hace menos de 1 h",
                ifelse(horas < 48, paste("hace", fb_dec(horas), "h"),
                       paste("hace", fb_dec(horas / 24), "días"))))
}

fb_ahora_local <- function() {
  as.POSIXct(format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = CFG$tz), tz = "UTC")
}

fb_horas_captura <- function(x) as.numeric(difftime(fb_ahora_local(), x, units = "hours"))
fb_horas_utc <- function(x) as.numeric(difftime(Sys.time(), x, units = "hours"))

fb_chip <- function(texto, icono = NULL, clase = NULL) {
  div(class = paste(c("fb-chip", clase), collapse = " "),
      if (!is.null(icono)) fb_icon(icono, 14),
      span(texto))
}

fb_section <- function(kicker, titulo, descripcion = NULL, derecha = NULL) {
  div(class = "fb-section",
      div(class = "fb-section__text",
          span(class = "fb-section__kicker", kicker),
          h2(class = "fb-section__title", titulo),
          if (!is.null(descripcion)) p(class = "fb-section__desc", descripcion)),
      if (!is.null(derecha)) div(class = "fb-section__right", derecha))
}

fb_kpi <- function(valor_id, etiqueta, icono, tono = "oliva", nota_id = NULL) {
  div(class = paste("fb-kpi", paste0("fb-kpi--", tono)),
      div(class = "fb-kpi__icon", fb_icon(icono, 21)),
      div(class = "fb-kpi__body",
          div(class = "fb-kpi__label", etiqueta),
          div(class = "fb-kpi__value", textOutput(valor_id, inline = TRUE)),
          if (!is.null(nota_id)) div(class = "fb-kpi__note", textOutput(nota_id, inline = TRUE))))
}

fb_stat <- function(etiqueta, valor_id, tono = "neutro") {
  div(class = paste("fb-stat", paste0("fb-stat--", tono)),
      span(class = "fb-stat__label", etiqueta),
      strong(class = "fb-stat__value", textOutput(valor_id, inline = TRUE)))
}

fb_card_title <- function(titulo, sub = NULL, derecha = NULL) {
  div(class = "fb-card__head",
      div(class = "fb-card__text",
          h3(titulo),
          if (!is.null(sub)) p(sub)),
      if (!is.null(derecha)) div(class = "fb-card__right", derecha))
}

fb_dt_lang <- function() {
  list(
    search = "Buscar:",
    lengthMenu = "Mostrar _MENU_ registros",
    info = "Mostrando _START_ a _END_ de _TOTAL_ registros",
    infoEmpty = "Sin registros",
    infoFiltered = "(filtrado de _MAX_)",
    zeroRecords = "No se encontraron registros",
    paginate = list(first = "Primera", last = "Última", "next" = "Siguiente", previous = "Anterior")
  )
}

fb_badge_estado <- function(x) {
  x <- as.character(x)
  lbl <- unname(FB$estado_lbl[x])
  lbl[is.na(lbl)] <- "s/d"
  cls <- ifelse(is.na(x) | !nzchar(x), "na", x)
  sprintf('<span class="fb-badge fb-badge--%s"><i></i>%s</span>',
          htmltools::htmlEscape(cls), htmltools::htmlEscape(lbl))
}

fb_plot_vacio <- function(mensaje) {
  plotly::plot_ly() |>
    plotly::layout(
      annotations = list(list(text = mensaje, showarrow = FALSE,
                              font = list(family = "Manrope, Inter, sans-serif", size = 13,
                                          color = unname(FB$colores[["muted"]])))),
      xaxis = list(visible = FALSE), yaxis = list(visible = FALSE),
      paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)") |>
    plotly::config(displayModeBar = FALSE)
}

fb_popup <- function(d) {
  antig <- ifelse(is.na(d$antiguedad_reporte_horas), "s/d",
                  paste0(fb_dec(d$antiguedad_reporte_horas), " h"))
  fecha <- format(d$fecha_reporte, "%d/%m/%Y %H:%M")
  sprintf(
    '<div class="fb-pop"><div class="fb-pop__head"><strong>%s</strong>%s</div><div class="fb-pop__grid"><span>Dirección</span><b>%s</b><span>Producto</span><b>%s</b><span>Saldo reportado</span><b>%s L</b><span>Reportado</span><b>%s</b><span>Antigüedad</span><b>%s</b></div><div class="fb-pop__foot">Fuente: ANH · saldo reportado por la estación. No garantiza disponibilidad ni venta al público.</div></div>',
    htmltools::htmlEscape(d$nombre), fb_badge_estado(d$saldo_estado),
    htmltools::htmlEscape(d$direccion), htmltools::htmlEscape(d$producto),
    fb_litros(d$saldo_litros), fecha, antig)
}

fb_hero_ui <- function() {
  arte <- '
  <svg viewBox="0 0 360 240" role="presentation" focusable="false">
    <defs>
      <linearGradient id="fbHeroGrad" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#91A77B" stop-opacity=".55"/>
        <stop offset="1" stop-color="#D9DED5" stop-opacity=".10"/>
      </linearGradient>
    </defs>
    <g fill="none" stroke="url(#fbHeroGrad)" stroke-width="1.1">
      <ellipse cx="214" cy="120" rx="112" ry="74"/>
      <ellipse cx="214" cy="120" rx="88" ry="56"/>
      <ellipse cx="214" cy="120" rx="62" ry="38"/>
      <ellipse cx="214" cy="120" rx="36" ry="21"/>
      <path d="M62 186c34-26 74-38 122-36 42 2 79 16 112 42"/>
      <path d="M48 158c38-24 82-34 128-31 40 3 76 16 108 39"/>
    </g>
    <g fill="#91A77B">
      <circle cx="128" cy="74" r="3.4"/><circle cx="302" cy="92" r="2.6"/>
      <circle cx="268" cy="178" r="3"/><circle cx="92" cy="132" r="2.4"/>
    </g>
    <path d="M232 72l-26 40h18l-6 34 30-46h-19l7-28z" fill="none" stroke="#D9DED5"
          stroke-width="1.4" stroke-linejoin="round" opacity=".8"/>
  </svg>'
  tags$section(class = "fb-hero", `aria-label` = "Encabezado de la plataforma",
               div(class = "fb-hero__main",
                   div(class = "fb-hero__brand",
                       span(class = "fb-logo", fb_icon("hoja", 22)),
                       span(class = "fb-hero__name", "Agente FuelBot v1 DAT-253"),
                       span(class = "fb-hero__ver", paste0("v", FB$version))),
                   h1(class = "fb-hero__title", "Chatbot de consultas sobre disponibilidad de combustibles"),
                   p(class = "fb-hero__sub",
                     "Monitoreo, análisis territorial y disponibilidad reportada de combustibles en el departamento de La Paz."),
                   uiOutput("hero_meta")),
               div(class = "fb-hero__art", `aria-hidden` = "true", HTML(arte)))
}

fb_footer_ui <- function() {
  tags$footer(class = "fb-footer",
              div(class = "fb-footer__brand",
                  span(class = "fb-logo fb-logo--sm", fb_icon("hoja", 16)),
                  div(strong("Agente FuelBot v1 DAT-253"),
                      span("Elaborado para la materia DAT-253 "))),
              div(class = "fb-footer__meta",
                  span("Fuentes: ANH y YPFB"),
                  span("Elaborador por: Iver Medina Balboa"),
                  span("Zona horaria: Bolivia (UTC−4)"),
                  span(paste0("Versión ", FB$version))),
              div(class = "fb-footer__state", uiOutput("pie_estado")))
}
