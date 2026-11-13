# FuelBot Lite · Extracción del portal ANH (saldo por estación y producto)
# Equivale a update/update_abastecimiento.py del repo sociedatos/bo-combustible, pero en R y solo La Paz.

COLUMNAS_SALDO <- c("fecha_actualizacion", "id_eess", "id_producto", "fecha_actualizacion_sistema", "saldo_litros",
                    "saldo_estado", "con_venta", "fecha_ultima_venta", "despacho_en_curso", "fecha_hora_despacho", "seguimiento_id")
COLUMNAS_ESTACION <- c("id_eess", "nombre", "direccion", "zona", "departamento_id", "lat", "lng")
COLUMNAS_FECHA_SALDO <- c("fecha_actualizacion", "fecha_actualizacion_sistema", "fecha_ultima_venta", "fecha_hora_despacho")

# Limpia y valida un data.frame de saldos (sirve para la API en vivo y para los CSV del repo)
normalizar_saldos <- function(df, captura = NULL) {
  adv <- character()
  df <- df |> rename(any_of(c(id_eess = "id", id_producto = "id_producto_abs",
                              fecha_actualizacion_sistema = "updated_at", lat = "latitud", lng = "longitud")))
  for (c in union(COLUMNAS_SALDO, COLUMNAS_ESTACION)) if (!c %in% names(df)) df[[c]] <- NA_character_
  df <- df |> mutate(across(everything(), as.character))
  if (!is.null(captura)) df$fecha_actualizacion <- captura
  if (all(is.na(df$departamento_id))) df$departamento_id <- as.character(CFG$departamento_id)
  for (c in COLUMNAS_FECHA_SALDO) df[[c]] <- norm_fecha(df[[c]])

  df <- df |> mutate(
    id_eess = as.character(suppressWarnings(as.integer(round(as.numeric(id_eess))))),
    id_producto = as.character(suppressWarnings(as.integer(round(as.numeric(id_producto))))),
    departamento_id = suppressWarnings(as.integer(round(as.numeric(departamento_id)))),
    saldo_estado = tolower(trimws(saldo_estado)),
    nombre = arreglar_mojibake(nombre), direccion = arreglar_mojibake(direccion), zona = arreglar_mojibake(zona))

  n0 <- nrow(df)
  df <- df |> filter(!is.na(id_eess), !is.na(id_producto), !is.na(fecha_actualizacion),
                     is.na(departamento_id) | departamento_id == CFG$departamento_id)
  if (nrow(df) < n0) adv <- c(adv, sprintf("%d filas descartadas (sin id/fecha o de otro departamento)", n0 - nrow(df)))

  raros <- setdiff(unique(na.omit(df$saldo_estado)), c("bajo", "medio", "alto"))
  if (length(raros)) adv <- c(adv, paste("saldo_estado inesperado:", paste(raros, collapse = ", ")))

  lat <- suppressWarnings(as.numeric(df$lat)); lng <- suppressWarnings(as.numeric(df$lng))
  fuera <- !is.na(lat) & !is.na(lng) & !(lat > -23 & lat < -9 & lng > -70 & lng < -57)   # recuadro aproximado de Bolivia
  if (any(fuera)) adv <- c(adv, sprintf("%d filas con coordenadas fuera de Bolivia (se anulan)", sum(fuera)))
  df$lat[fuera] <- NA_character_; df$lng[fuera] <- NA_character_

  df <- df[!duplicated(df[, c("fecha_actualizacion", "id_eess", "id_producto")], fromLast = TRUE), ]
  # para estaciones, quedarse con el dato MÁS reciente de cada una
  estaciones <- df |> arrange(desc(fecha_actualizacion)) |> distinct(id_eess, .keep_all = TRUE) |>
    select(all_of(COLUMNAS_ESTACION)) |> mutate(departamento_id = as.character(departamento_id))
  list(saldos = df |> select(all_of(COLUMNAS_SALDO)), estaciones = estaciones, advertencias = adv)
}

extraer_anh <- function(departamento = CFG$departamento_id, productos = as.integer(names(CFG$productos))) {
  captura <- ahora_bo()
  crudos <- list(); filas <- list()
  for (p in productos) {
    texto <- pedir(paste0(CFG$anh_base, "/estaciones"), list(departamento = departamento, producto = p))
    js <- jsonlite::fromJSON(texto, simplifyVector = FALSE)
    crudos[[as.character(p)]] <- js
    if (!identical(js$strMensaje, "OK") || !is.list(js$oResultado) || length(js$oResultado) == 0) next
    filas[[length(filas) + 1]] <- map_dfr(js$oResultado, registro_a_fila) |> mutate(id_producto = as.character(p))
  }
  if (!length(filas)) stop("El portal ANH no devolvió estaciones (¿cambió la API o hay bloqueo?)", call. = FALSE)
  crudo <- guardar_crudo(jsonlite::toJSON(crudos, auto_unbox = TRUE, null = "null"), "anh")
  res <- normalizar_saldos(bind_rows(filas), captura)
  res$crudo <- crudo
  res
}
