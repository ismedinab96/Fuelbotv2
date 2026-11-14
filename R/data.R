# FuelBot Lite · acceso de lectura compartido por la interfaz y los módulos
# Reutiliza la conexión cacheada de agente/agente_gemini.R (rol agente_ro).
consultar <- function(sql) {
  intento <- function() DBI::dbGetQuery(con_ro(), sql)
  tryCatch(intento(), error = function(e) {
    .fb$con <- NULL
    tryCatch(intento(), error = function(e2) NULL)
  })
}
