# FuelBot Lite · Bot conversacional de Telegram en R (Long Polling + Gemini + PostgreSQL solo lectura)
# Reutiliza pipeline/00_config.R y agente/agente_gemini.R (rol agente_ro + guardia validar_sql()).
# Ejecutar desde la raíz del proyecto: Rscript telegram/bot_telegram.R
# Verificación sin conexión a Telegram:  Rscript telegram/bot_telegram.R --check

if (!file.exists("pipeline/00_config.R") && file.exists("../pipeline/00_config.R")) {
  setwd("..")
}
if (!file.exists("pipeline/00_config.R") || !file.exists("agente/agente_gemini.R")) {
  stop("Ejecuta este script desde la raíz del proyecto FuelBot Lite.", call. = FALSE)
}

source("pipeline/00_config.R", encoding = "UTF-8")
source("agente/agente_gemini.R", encoding = "UTF-8")

TELEGRAM_API <- "https://api.telegram.org"
MAX_PREGUNTAS_MIN <- 3L
MAX_PREGUNTAS_DIA <- 30L
MAX_HISTORIAL_MENSAJES <- 6L

# Estado en memoria por chat_id (historial, última evidencia SQL y control de cuota)
.tg <- new.env(parent = emptyenv())
.tg$historial <- list()
.tg$pasos     <- list()
.tg$marcas    <- list()
.tg$total     <- list()
.tg$fecha     <- list()

tg_token <- function() {
  env("TELEGRAM_BOT_TOKEN", requerido = TRUE)
}

tg_llamar <- function(metodo, body = list(), timeout = 35) {
  resp <- request(paste0(TELEGRAM_API, "/bot", tg_token(), "/", metodo)) |>
    req_body_json(body, auto_unbox = TRUE) |>
    req_timeout(timeout) |>
    req_error(is_error = function(r) FALSE) |>
    req_perform()

  datos <- tryCatch(resp_body_json(resp, simplifyVector = FALSE), error = function(e) NULL)
  if (resp_status(resp) >= 400 || is.null(datos) || !isTRUE(datos$ok)) {
    desc <- if (!is.null(datos$description)) datos$description else paste("HTTP", resp_status(resp))
    stop("Error de Telegram (", metodo, "): ", desc, call. = FALSE)
  }
  datos
}

tg_accion <- function(chat_id, accion = "typing") {
  tryCatch(
    tg_llamar("sendChatAction", list(chat_id = chat_id, action = accion), timeout = 10),
    error = function(e) NULL
  )
}

partir_texto <- function(texto, max_chars = 4000L) {
  texto <- trimws(as.character(texto %||% ""))
  if (!nzchar(texto)) return(character(0))
  if (nchar(texto) <= max_chars) return(texto)

  bloques <- character(0)
  resto <- texto
  while (nchar(resto) > max_chars) {
    trozo <- substr(resto, 1L, max_chars)
    saltos <- gregexpr("\n", trozo, fixed = TRUE)[[1L]]
    ultimo_salto <- max(saltos)
    corte <- if (length(saltos) && ultimo_salto > as.integer(max_chars * 0.5)) ultimo_salto else max_chars
    bloques <- c(bloques, trimws(substr(resto, 1L, corte), which = "right"))
    resto <- trimws(substr(resto, corte + 1L, nchar(resto)), which = "left")
  }
  if (nzchar(resto)) bloques <- c(bloques, resto)
  bloques
}

tg_enviar <- function(chat_id, texto) {
  bloques <- partir_texto(texto, max_chars = 4000L)
  for (bloque in bloques) {
    tg_llamar("sendMessage", list(chat_id = chat_id, text = bloque), timeout = 30)
  }
  invisible(length(bloques))
}

formatear_sql_pasos <- function(pasos) {
  if (is.null(pasos) || !length(pasos)) {
    return("Aún no hay consultas SQL registradas en esta conversación. Haz una pregunta primero.")
  }

  detalles <- vapply(seq_along(pasos), function(i) {
    p <- pasos[[i]]
    r <- p$resultado %||% list()
    if (!is.null(r$error)) {
      resumen <- paste("error:", r$error)
    } else {
      n_filas <- length(r$filas %||% list())
      resumen <- paste0(n_filas, " fila(s)", if (isTRUE(r$recortado)) " · recortado a 50" else "")
    }
    sprintf("Consulta %d (%s):\n%s", i, resumen, trimws(p$consulta %||% ""))
  }, character(1))

  paste0(
    "Evidencia SQL de la última respuesta (rol de solo lectura agente_ro):\n\n",
    paste(detalles, collapse = "\n\n")
  )
}

mensaje_bienvenida <- function() {
  paste(
    "Hola, soy FuelBot La Paz (DAT-253).",
    "Respondo preguntas sobre combustibles en estaciones de servicio del departamento de La Paz consultando las vistas de ANH (saldos por estación) y YPFB (despachos y programación) en modo de solo lectura.",
    "",
    "Ejemplos de consulta:",
    "- ¿Cuántas estaciones reportan saldo alto de gasolina especial?",
    "- ¿Qué estaciones de El Alto reportan saldo bajo de diésel?",
    "- ¿Cuántos litros despachó YPFB el último día?",
    "",
    "Comandos disponibles:",
    "/sql - Ver las consultas SQL de evidencia de tu última pregunta",
    "/limpiar - Reiniciar el historial de conversación",
    "/ayuda - Mostrar esta ayuda",
    "",
    "Nota metodológica: un saldo reportado por ANH no garantiza disponibilidad física en surtidor. Cada respuesta cita fuente, fecha de reporte y fecha de captura (hora de Bolivia UTC-4).",
    sep = "\n"
  )
}

verificar_cuota <- function(cid) {
  ahora <- as.numeric(Sys.time())
  hoy <- as.character(Sys.Date())

  if (!identical(.tg$fecha[[cid]], hoy)) {
    .tg$fecha[[cid]] <- hoy
    .tg$total[[cid]] <- 0L
  }

  marcas <- .tg$marcas[[cid]] %||% numeric(0)
  marcas <- marcas[marcas > (ahora - 60)]
  total <- .tg$total[[cid]] %||% 0L

  if (length(marcas) >= MAX_PREGUNTAS_MIN || total >= MAX_PREGUNTAS_DIA) {
    .tg$marcas[[cid]] <- marcas
    return(list(
      ok = FALSE,
      mensaje = sprintf(
        "Límite de cuota alcanzado: máximo %d preguntas por minuto y %d por día. Espera un momento e inténtalo de nuevo.",
        MAX_PREGUNTAS_MIN, MAX_PREGUNTAS_DIA
      )
    ))
  }

  .tg$marcas[[cid]] <- c(marcas, ahora)
  .tg$total[[cid]] <- total + 1L
  list(ok = TRUE)
}

procesar_mensaje <- function(chat_id, texto) {
  q <- trimws(as.character(texto %||% ""))
  if (!nzchar(q)) return(NULL)

  cid <- as.character(chat_id)

  if (startsWith(q, "/")) {
    primer_token <- strsplit(q, "\\s+")[[1L]][1L]
    cmd <- tolower(sub("@.*$", "", primer_token))

    if (cmd %in% c("/start", "/ayuda", "/help")) {
      return(mensaje_bienvenida())
    }
    if (cmd %in% c("/limpiar", "/reset")) {
      .tg$historial[[cid]] <- list()
      .tg$pasos[[cid]] <- NULL
      return("Historial de conversación reiniciado. Puedes hacer una nueva pregunta.")
    }
    if (cmd == "/sql") {
      return(formatear_sql_pasos(.tg$pasos[[cid]]))
    }
    return("Comando no reconocido. Envía tu pregunta en texto o usa /ayuda para ver los comandos disponibles.")
  }

  cuota <- verificar_cuota(cid)
  if (!isTRUE(cuota$ok)) return(cuota$mensaje)

  tg_accion(chat_id, "typing")
  hist_actual <- .tg$historial[[cid]] %||% list()

  res <- tryCatch(
    preguntar(
      q,
      historial = hist_actual,
      on_paso = function(n, sql, r) tg_accion(chat_id, "typing")
    ),
    error = function(e) {
      list(
        respuesta = paste("No pude responder en este momento:", conditionMessage(e)),
        pasos = list(),
        error = TRUE
      )
    }
  )

  respuesta <- trimws(res$respuesta %||% "Sin respuesta.")
  pasos <- res$pasos %||% list()

  if (!isTRUE(res$error)) {
    nuevo_hist <- c(
      hist_actual,
      list(
        list(role = "user", parts = list(list(text = substr(q, 1L, 500L)))),
        list(role = "model", parts = list(list(text = respuesta)))
      )
    )
    .tg$historial[[cid]] <- tail(nuevo_hist, MAX_HISTORIAL_MENSAJES)
    .tg$pasos[[cid]] <- pasos
  }

  if (length(pasos) > 0L) {
    respuesta <- paste0(
      respuesta,
      sprintf(
        "\n\n[Evidencia SQL: %d consulta(s) de solo lectura ejecutada(s). Envía /sql para ver el código SQL.]",
        length(pasos)
      )
    )
  }

  respuesta
}

iniciar_bot <- function() {
  tg_token()
  me <- tg_llamar("getMe", timeout = 15)$result
  tryCatch(tg_llamar("deleteWebhook", list(drop_pending_updates = FALSE), timeout = 15), error = function(e) NULL)

  cat(sprintf(
    "[%s] FuelBot Telegram iniciado: @%s (id: %s)\n",
    ahora_bo(), me$username %||% "desconocido", as.character(me$id %||% "?")
  ))
  cat("Esperando mensajes... (Ctrl+C para detener)\n")

  offset <- 0
  repeat {
    res <- tryCatch(
      tg_llamar(
        "getUpdates",
        list(offset = offset, timeout = 25, allowed_updates = list("message")),
        timeout = 35
      ),
      error = function(e) {
        cat(sprintf("[%s] Error en getUpdates: %s\n", ahora_bo(), conditionMessage(e)))
        Sys.sleep(5)
        NULL
      }
    )

    if (is.null(res) || !length(res$result)) next

    for (upd in res$result) {
      if (!is.null(upd$update_id)) {
        offset <- max(offset, as.numeric(upd$update_id) + 1)
      }
      msg <- upd$message
      if (is.null(msg) || is.null(msg$text) || is.null(msg$chat$id)) next

      chat_id <- msg$chat$id
      cat(sprintf("[%s] chat %s -> %s\n", ahora_bo(), as.character(chat_id), substr(msg$text, 1L, 120L)))

      respuesta <- procesar_mensaje(chat_id, msg$text)
      if (!is.null(respuesta) && nzchar(respuesta)) {
        tryCatch(
          tg_enviar(chat_id, respuesta),
          error = function(e) {
            cat(sprintf("[%s] Error enviando respuesta a %s: %s\n", ahora_bo(), as.character(chat_id), conditionMessage(e)))
          }
        )
      }
    }
  }
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if ("--check" %in% args) {
    cat("[ok] Sintaxis y módulos de telegram/bot_telegram.R cargados correctamente.\n")
  } else {
    iniciar_bot()
  }
}
