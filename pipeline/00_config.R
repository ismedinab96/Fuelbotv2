# FuelBot Lite · Configuración y utilidades comunes (todo en R)
suppressPackageStartupMessages({
  library(httr2); library(jsonlite); library(dplyr); library(purrr); library(stringr)
})

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

env <- function(nombre, defecto = NULL, requerido = FALSE) {
  v <- Sys.getenv(nombre, unset = "")
  if (!nzchar(v)) {
    if (requerido) stop("Falta la variable de entorno ", nombre, " (revisa tu archivo .Renviron)", call. = FALSE)
    return(defecto)
  }
  v
}

CFG <- list(
  departamento_id = as.integer(env("DEPARTAMENTO_ID", "2")),            # 2 = La Paz (codificación INE usada por ANH)
  distritos_ypfb  = trimws(strsplit(env("DISTRITOS_YPFB", "LPZ"), ",")[[1]]),
  productos       = c(`0` = "Gasolina Especial", `1` = "Di\u00e9sel Oil", `2` = "Gasolina Premium", `3` = "Di\u00e9sel ULS"),
  anh_base        = "https://abastecimiento.prod.anh.gob.bo/api",
  ypfb_url        = "https://consulta.ypfb.gob.bo/",
  user_agent      = env("USER_AGENT", "FuelBotLaPaz-Academico/1.0 (contacto: CAMBIAR@correo.com)"),
  tz              = "America/La_Paz",
  raw_dir         = env("RAW_DIR", "data/raw"),
  repo_raw        = "https://raw.githubusercontent.com/sociedatos/bo-combustible/main",
  repo_api        = "https://api.github.com/repos/sociedatos/bo-combustible/contents"
)

ahora_bo <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = CFG$tz)

# ── HTTP educado: user-agent identificable, límite de ritmo y reintentos ────
pedir <- function(url, query = list(), reintentos = 3, destino = NULL) {
  req <- request(url) |>
    req_user_agent(CFG$user_agent) |>
    req_timeout(60) |>
    req_throttle(rate = 20 / 60) |>
    req_retry(max_tries = reintentos, backoff = function(i) 2^i)
  if (length(query)) req <- req_url_query(req, !!!query)
  if (is.null(destino)) resp_body_string(req_perform(req)) else { req_perform(req, path = destino); destino }
}

# ── Copia cruda comprimida + huella SHA-256 (trazabilidad) ──────────────────
guardar_crudo <- function(texto, fuente, ext = "json") {
  dir <- file.path(CFG$raw_dir, fuente)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  ruta <- file.path(dir, paste0(format(Sys.time(), "%Y%m%d_%H%M%S", tz = CFG$tz), ".", ext, ".gz"))
  con <- gzfile(ruta, "w", encoding = "UTF-8"); writeLines(texto, con, useBytes = TRUE); close(con)
  list(ruta = ruta, sha256 = digest::digest(ruta, algo = "sha256", file = TRUE))
}

# ── Utilidades de limpieza ──────────────────────────────────────────────────
registro_a_fila <- function(x) {
  tibble::as_tibble(lapply(x, function(v) if (is.null(v) || length(v) != 1 || is.list(v)) NA_character_ else as.character(v)))
}

# "2026-11-08T23:37:41.123Z" / "2026-11-08 23:37:41" -> "2026-11-08 23:37:41" (NA si no es válida)
norm_fecha <- function(x) {
  x <- as.character(x)
  x <- sub("\\.\\d+", "", x)
  x <- sub("(?<=\\d{2}:\\d{2}:\\d{2})(Z|[+-]\\d{2}:?\\d{2})$", "", x, perl = TRUE)
  x <- sub("T", " ", x, fixed = TRUE)
  x[!grepl("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$", x)] <- NA_character_
  x
}

# Repara texto UTF-8 "doble codificado" (p. ej. "AURÃ\u008dFERA" -> "AURÍFERA")
arreglar_mojibake <- function(x) {
  x <- as.character(x)
  idx <- which(!is.na(x) & grepl("\u00c3", x, fixed = TRUE))
  if (length(idx)) {
    y <- suppressWarnings(iconv(x[idx], from = "UTF-8", to = "latin1"))
    Encoding(y) <- "UTF-8"
    ok <- !is.na(y) & validUTF8(y)
    x[idx[ok]] <- y[ok]
  }
  x
}

# ── Conexiones a Supabase (Postgres) ────────────────────────────────────────
conectar <- function(usuario, clave) {
  DBI::dbConnect(RPostgres::Postgres(),
    host = env("SUPABASE_HOST", requerido = TRUE), port = as.integer(env("SUPABASE_PORT", "5432")),
    dbname = env("SUPABASE_DB", "postgres"), user = usuario, password = clave, sslmode = "require")
}
con_escritura <- function() conectar(env("SUPABASE_USER", requerido = TRUE), env("SUPABASE_PASSWORD", requerido = TRUE))
con_lectura   <- function() conectar(env("SUPABASE_RO_USER", requerido = TRUE), env("SUPABASE_RO_PASSWORD", requerido = TRUE))
