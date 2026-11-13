# FuelBot Lite · Agente en R con Gemini (function calling + herramienta SQL de solo lectura)
# Es el equivalente en R del cuaderno "Agente IA SQL" (Python): mismo ciclo pregunta -> consulta SQL -> respuesta.
# Requiere haber cargado pipeline/00_config.R (env(), pedir(), con_lectura()).

MAX_FILAS  <- 50
MAX_PASOS  <- 6
GEMINI_API <- "https://generativelanguage.googleapis.com/v1beta"
.fb <- new.env()   # caché: modelo elegido y conexión de solo lectura

# ── Guardia SQL: primera capa. La segunda (la real) es el rol agente_ro de Postgres ───────────────
PROHIBIDAS <- paste0("\\b(insert|update|delete|drop|alter|create|replace|grant|revoke|truncate|copy|call|execute|merge|",
                     "vacuum|listen|notify|set|reset|do|begin|commit|rollback)\\b|pg_|information_schema|dblink|lo_import|lo_export|--|/\\*")

validar_sql <- function(consulta) {
  sql <- trimws(sub(";+\\s*$", "", trimws(consulta %||% "")))
  if (!grepl("^(select|with)\\b", sql, ignore.case = TRUE, perl = TRUE)) return(list(error = "Solo se permiten consultas SELECT."))
  if (grepl(";", sql, fixed = TRUE)) return(list(error = "Solo se permite una consulta por vez."))
  if (grepl(PROHIBIDAS, sql, ignore.case = TRUE, perl = TRUE)) return(list(error = "La consulta contiene una instrucci\u00f3n no permitida."))
  list(sql = sql)
}

filas_a_lista <- function(df) {
  df[] <- lapply(df, function(x) {
    if (inherits(x, "integer64")) as.numeric(x)
    else if (inherits(x, c("POSIXt", "Date", "factor"))) as.character(x)
    else x
  })
  lapply(seq_len(nrow(df)), function(i) unname(lapply(df[i, , drop = FALSE], function(v) if (length(v) == 1 && is.na(v)) NULL else v)))
}

con_ro <- function() {
  if (is.null(.fb$con) || !DBI::dbIsValid(.fb$con)) .fb$con <- con_lectura()
  .fb$con
}

ejecutar_sql <- function(consulta) {
  v <- validar_sql(consulta)
  if (!is.null(v$error)) return(v)
  tryCatch({
    df <- DBI::dbGetQuery(con_ro(), paste0("select * from (", v$sql, ") as q limit ", MAX_FILAS + 1))
    list(columnas = as.list(names(df)), filas = filas_a_lista(head(df, MAX_FILAS)), recortado = nrow(df) > MAX_FILAS)
  }, error = function(e) list(error = paste("Error de SQL:", substr(conditionMessage(e), 1, 300))))
}

# ── Gemini (API REST) ────────────────────────────────────────────────────────────────────────────
elegir_modelo <- function() {
  manual <- env("GEMINI_MODEL", "")
  if (nzchar(manual)) return(manual)
  if (!is.null(.fb$modelo)) return(.fb$modelo)
  resp <- request(paste0(GEMINI_API, "/models")) |> req_url_query(pageSize = 200) |>
    req_headers(`x-goog-api-key` = env("GEMINI_API_KEY", requerido = TRUE)) |> req_perform()
  ms <- resp_body_json(resp, simplifyVector = FALSE)$models
  nombres <- vapply(Filter(function(m) "generateContent" %in% unlist(m$supportedGenerationMethods), ms),
                    function(m) sub("^models/", "", m$name), "")
  preferidos <- c("gemini-3.5-flash-lite", "gemini-3.1-flash-lite", "gemini-2.5-flash-lite")   # mismos del cuaderno del taller
  elegido <- preferidos[preferidos %in% nombres][1]
  if (is.na(elegido)) elegido <- grep("flash-lite", nombres, value = TRUE)[!grepl("preview", grep("flash-lite", nombres, value = TRUE))][1]
  if (is.na(elegido)) stop("Tu clave no muestra modelos Flash-Lite. Define GEMINI_MODEL en .Renviron.", call. = FALSE)
  .fb$modelo <- elegido
  elegido
}

DECLARACION <- list(
  name = "ejecutar_sql",
  description = "Ejecuta UNA consulta SELECT de solo lectura en la base PostgreSQL de FuelBot La Paz. Devuelve columnas y hasta 50 filas.",
  parameters = list(type = "OBJECT",
                    properties = list(consulta = list(type = "STRING", description = "Consulta SQL SELECT en dialecto PostgreSQL")),
                    required = list("consulta")))

gemini_generar <- function(contents, sistema, modelo) {
  body <- list(contents = contents,
               systemInstruction = list(parts = list(list(text = sistema))),
               tools = list(list(functionDeclarations = list(DECLARACION))),
               generationConfig = list(temperature = 0.1))
  resp <- request(paste0(GEMINI_API, "/models/", modelo, ":generateContent")) |>
    req_headers(`x-goog-api-key` = env("GEMINI_API_KEY", requerido = TRUE)) |>
    req_body_json(body, auto_unbox = TRUE, null = "null", na = "null") |>
    req_timeout(90) |>
    req_retry(max_tries = 3, is_transient = function(r) resp_status(r) %in% c(429, 500, 503), backoff = function(i) 15 * i) |>
    req_error(is_error = function(r) FALSE) |>
    req_perform()
  if (resp_status(resp) == 429) stop("Se alcanz\u00f3 el l\u00edmite de uso gratuito de Gemini. Espera un minuto e int\u00e9ntalo de nuevo.", call. = FALSE)
  if (resp_status(resp) >= 400) stop("Error de Gemini (", resp_status(resp), "): ", substr(resp_body_string(resp), 1, 300), call. = FALSE)
  resp_body_json(resp, simplifyVector = FALSE)
}

SISTEMA <- paste(readLines(file.path(if (dir.exists("agente")) "agente" else ".", "instrucciones.txt"), encoding = "UTF-8"), collapse = "\n")

# ── Ciclo del agente ─────────────────────────────────────────────────────────────────────────────
# historial: lista de turnos previos list(role = "user"|"model", parts = list(list(text = ...))) (solo texto)
# on_paso(n, consulta, resultado): callback para mostrar progreso en la interfaz
preguntar <- function(pregunta, historial = list(), on_paso = NULL) {
  modelo <- elegir_modelo()
  contents <- c(historial, list(list(role = "user", parts = list(list(text = substr(pregunta, 1, 500))))))
  pasos <- list()
  for (i in seq_len(MAX_PASOS)) {
    r <- gemini_generar(contents, SISTEMA, modelo)
    cand <- if (length(r$candidates)) r$candidates[[1]] else NULL
    if (is.null(cand$content$parts)) {
      motivo <- cand$finishReason %||% r$promptFeedback$blockReason %||% "desconocido"
      return(list(respuesta = paste0("El modelo no devolvi\u00f3 una respuesta (motivo: ", motivo, ")."), pasos = pasos, modelo = modelo))
    }
    partes <- cand$content$parts
    llamadas <- Filter(function(p) !is.null(p$functionCall), partes)
    if (!length(llamadas)) {
      texto <- vapply(Filter(function(p) !is.null(p$text), partes), function(p) p$text, "")
      return(list(respuesta = trimws(paste(texto, collapse = "\n")), pasos = pasos, modelo = modelo))
    }
    contents[[length(contents) + 1]] <- cand$content          # se devuelve tal cual (conserva firmas de razonamiento)
    respuestas <- lapply(llamadas, function(p) {
      consulta <- p$functionCall$args$consulta %||% ""
      res <- ejecutar_sql(consulta)
      pasos[[length(pasos) + 1]] <<- list(consulta = consulta, resultado = res)
      if (!is.null(on_paso)) on_paso(length(pasos), consulta, res)
      list(functionResponse = list(name = p$functionCall$name, response = res))
    })
    contents[[length(contents) + 1]] <- list(role = "user", parts = respuestas)
  }
  list(respuesta = "Alcanc\u00e9 el m\u00e1ximo de pasos sin una respuesta final. Intenta reformular la pregunta.", pasos = pasos, modelo = modelo)
}
