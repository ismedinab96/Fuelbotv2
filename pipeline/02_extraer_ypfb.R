# FuelBot Lite · Extracción de YPFB (despachos, programación, resumen por distrito)
# Equivale a update/update_ypfb.py: la página trae un bloque <script id="datos-publicos"> con JSON.

COL_DESP <- c("clave", "fecha_captura", "fecha_datos", "distrito_codigo", "distrito_nombre", "producto_general",
              "producto_despachado", "familia", "cliente", "estacion", "placa_despacho", "cantidad_despachada", "unidad",
              "fecha_despacho_programado", "fecha_despacho_efectivo", "fecha_despacho_efectivo_hora",
              "despacho_confirmado", "ambito")
COL_PROG <- c("clave", "fecha_captura", "fecha_datos", "distrito_codigo", "distrito_nombre", "producto_general",
              "producto", "familia", "cliente", "volumen_programado", "canal", "atendida")
COL_RES  <- c("fecha_captura", "fecha_datos", "distrito_codigo", "distrito_nombre", "producto_general",
              "litros_programados", "litros_despachados", "litros_pendientes_confirmacion")

completar <- function(df, cols) { for (c in cols) if (!c %in% names(df)) df[[c]] <- NA_character_; df |> mutate(across(everything(), as.character)) }

# Clave estable (md5) + número de repetición para no colapsar filas idénticas legítimas
con_clave <- function(df, campos) {
  base <- do.call(paste, c(lapply(campos, function(c) df[[c]]), sep = "|"))
  df$clave <- paste0(vapply(base, digest::digest, "", algo = "md5", serialize = FALSE), "-", ave(seq_along(base), base, FUN = seq_along))
  df
}

normalizar_despachos <- function(df) {
  df <- completar(df, setdiff(COL_DESP, "clave")) |>
    filter(distrito_codigo %in% CFG$distritos_ypfb) |>
    mutate(fecha_captura = norm_fecha(fecha_captura), cliente = arreglar_mojibake(cliente), estacion = arreglar_mojibake(estacion)) |>
    filter(!is.na(fecha_captura))
  if (!nrow(df)) return(df |> mutate(clave = character()) |> select(any_of(COL_DESP)))
  con_clave(df, c("fecha_datos", "distrito_codigo", "placa_despacho", "fecha_despacho_efectivo_hora", "producto_despachado", "estacion", "cantidad_despachada")) |>
    select(all_of(COL_DESP))
}

normalizar_programacion <- function(df) {
  df <- completar(df, setdiff(COL_PROG, "clave")) |>
    filter(distrito_codigo %in% CFG$distritos_ypfb) |>
    mutate(fecha_captura = norm_fecha(fecha_captura), cliente = arreglar_mojibake(cliente)) |>
    filter(!is.na(fecha_captura))
  if (!nrow(df)) return(df |> mutate(clave = character()) |> select(any_of(COL_PROG)))
  con_clave(df, c("fecha_datos", "distrito_codigo", "producto", "cliente", "volumen_programado")) |> select(all_of(COL_PROG))
}

normalizar_resumen <- function(df) {
  completar(df, COL_RES) |>
    filter(distrito_codigo %in% CFG$distritos_ypfb) |>
    mutate(fecha_captura = norm_fecha(fecha_captura)) |>
    filter(!is.na(fecha_captura)) |> select(all_of(COL_RES))
}

extraer_payload_ypfb <- function(html) {
  m <- regmatches(html, regexec('<script type=["\']application/json["\'] id=["\']datos-publicos["\']>([\\s\\S]*?)</script>', html, perl = TRUE))[[1]]
  if (length(m) < 2) stop("No encontré el bloque 'datos-publicos' en la página de YPFB (¿cambió el sitio?)", call. = FALSE)
  jsonlite::fromJSON(m[2], simplifyVector = FALSE)
}

procesar_payload_ypfb <- function(payload, captura = ahora_bo()) {
  distritos <- payload$distritos %||% list()
  mapa <- setNames(distritos, vapply(distritos, function(d) as.character(d$id), ""))
  con_meta <- function(registro, meta) registro_a_fila(modifyList(registro, meta))
  desp <- list(); prog <- list(); res <- list()
  for (id in names(payload$datos)) {
    info <- mapa[[id]]; cod <- info$codigo %||% ""
    if (!(cod %in% CFG$distritos_ypfb)) next
    for (prod in names(payload$datos[[id]])) {
      pd <- payload$datos[[id]][[prod]]
      meta <- list(fecha_captura = captura, fecha_datos = payload$fecha_datos, distrito_id = id,
                   distrito_codigo = cod, distrito_nombre = info$nombre %||% "", producto_general = prod)
      if (!is.null(pd$resumen)) res[[length(res) + 1]] <- con_meta(pd$resumen, meta)
      desp <- c(desp, lapply(pd$despachos %||% list(), con_meta, meta))
      prog <- c(prog, lapply(pd$programacion %||% list(), con_meta, meta))
    }
  }
  list(despachos = normalizar_despachos(bind_rows(desp)),
       programacion = normalizar_programacion(bind_rows(prog)),
       resumen = normalizar_resumen(bind_rows(res)))
}

extraer_ypfb <- function() {
  html <- pedir(CFG$ypfb_url)
  crudo <- guardar_crudo(html, "ypfb", "html")
  out <- procesar_payload_ypfb(extraer_payload_ypfb(html))
  out$crudo <- crudo
  out$advertencias <- if (nrow(out$despachos) + nrow(out$programacion) == 0) "La página no trajo filas para los distritos configurados" else character()
  out
}
