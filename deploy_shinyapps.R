# FuelBot Lite · Despliegue seguro en shinyapps.io (plan gratuito)
# Empaqueta SOLO los archivos de la interfaz Shiny y un .Renviron sanitizado con credenciales de lectura (agente_ro).
# Nunca sube credenciales de escritura (SUPABASE_USER/PASSWORD), TELEGRAM_BOT_TOKEN, docs/, data/raw/ ni sql/.
#
# Uso desde la raíz del proyecto:
#   Rscript deploy_shinyapps.R
#   Rscript deploy_shinyapps.R --dry-run   (verifica paquete y archivos sin subir)

APP_FILES_SHINY <- c(
  "app.R",
  "agente/agente_gemini.R",
  "agente/instrucciones.txt",
  "pipeline/00_config.R",
  "R/theme.R",
  "R/components.R",
  "R/data.R",
  "R/mod_resumen.R",
  "R/mod_mapa.R",
  "R/mod_ypfb.R",
  "R/mod_agente.R",
  "www/motion.css",
  "www/custom.js"
)

VARS_REQUERIDAS_RO <- c("SUPABASE_HOST", "SUPABASE_RO_USER", "SUPABASE_RO_PASSWORD", "GEMINI_API_KEY")
VARS_OPCIONALES_APP <- c("SUPABASE_PORT", "SUPABASE_DB", "GEMINI_MODEL", "DEPARTAMENTO_ID", "DISTRITOS_YPFB", "USER_AGENT")

obtener_env <- function(nombre, defecto = "") {
  v <- Sys.getenv(nombre, unset = "")
  if (nzchar(v)) v else defecto
}

construir_renviron_ro <- function(destino) {
  lineas <- character(0)
  nombres <- character(0)
  for (v in c(VARS_REQUERIDAS_RO, VARS_OPCIONALES_APP)) {
    val <- gsub("[\r\n]", "", Sys.getenv(v, unset = ""))
    if (nzchar(val)) {
      lineas <- c(lineas, sprintf("%s=%s", v, val))
      nombres <- c(nombres, v)
    }
  }
  writeLines(lineas, con = destino, useBytes = TRUE)
  invisible(nombres)
}

configurar_cuenta_shinyapps <- function() {
  nombre  <- obtener_env("SHINYAPPS_ACCOUNT")
  token   <- obtener_env("SHINYAPPS_TOKEN")
  secret  <- obtener_env("SHINYAPPS_SECRET")

  if (nzchar(nombre) && nzchar(token) && nzchar(secret)) {
    rsconnect::setAccountInfo(name = nombre, token = token, secret = secret)
    return(nombre)
  }

  cuentas <- rsconnect::accounts(server = "shinyapps.io")
  if (nrow(cuentas) == 0L) {
    stop(
      paste(
        "No hay una cuenta de shinyapps.io configurada.",
        "Crea una cuenta gratuita en https://www.shinyapps.io/, ve a Account -> Tokens -> Show y agrega en tu .Renviron:",
        "  SHINYAPPS_ACCOUNT=tu_usuario",
        "  SHINYAPPS_TOKEN=tu_token",
        "  SHINYAPPS_SECRET=tu_secret",
        "O ejecuta rsconnect::setAccountInfo(name=..., token=..., secret=...) en R.",
        sep = "\n"
      ),
      call. = FALSE
    )
  }
  if (nzchar(nombre)) nombre else cuentas$name[1L]
}

desplegar_shinyapps <- function(dry_run = FALSE) {
  if (!file.exists("app.R")) {
    stop("Ejecuta deploy_shinyapps.R desde la raíz del proyecto FuelBot Lite.", call. = FALSE)
  }
  if (!requireNamespace("rsconnect", quietly = TRUE)) {
    stop("Falta el paquete 'rsconnect'. Instálalo con: install.packages('rsconnect')", call. = FALSE)
  }

  faltantes <- VARS_REQUERIDAS_RO[!nzchar(Sys.getenv(VARS_REQUERIDAS_RO, unset = ""))]
  if (length(faltantes)) {
    stop(
      "Faltan variables de entorno requeridas para lectura en .Renviron: ",
      paste(faltantes, collapse = ", "),
      call. = FALSE
    )
  }

  sin_archivo <- APP_FILES_SHINY[!file.exists(APP_FILES_SHINY)]
  if (length(sin_archivo)) {
    stop("Faltan archivos necesarios para el despliegue: ", paste(sin_archivo, collapse = ", "), call. = FALSE)
  }

  staging_dir <- tempfile("fuelbot_shiny_")
  dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(staging_dir, recursive = TRUE, force = TRUE), add = TRUE)

  for (rel in APP_FILES_SHINY) {
    dest <- file.path(staging_dir, rel)
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    ok <- file.copy(rel, dest, overwrite = TRUE)
    if (!ok) stop("No se pudo copiar el archivo al paquete temporal: ", rel, call. = FALSE)
  }

  vars_incluidas <- construir_renviron_ro(file.path(staging_dir, ".Renviron"))
  archivos_bundle <- c(APP_FILES_SHINY, ".Renviron")
  app_name <- obtener_env("SHINYAPPS_APP_NAME", "fuelbot-lapaz")

  cat(sprintf("Paquete preparado (%d archivos). Variables incluidas (.Renviron solo lectura): %s\n",
              length(archivos_bundle), paste(vars_incluidas, collapse = ", ")))

  if (isTRUE(dry_run)) {
    cat("[ok] Modo --dry-run completado. No se subió nada a shinyapps.io.\n")
    return(invisible(TRUE))
  }

  cuenta <- configurar_cuenta_shinyapps()
  cat(sprintf("Desplegando '%s' en shinyapps.io (cuenta: %s)...\n", app_name, cuenta))

  rsconnect::deployApp(
    appDir = staging_dir,
    appFiles = archivos_bundle,
    appName = app_name,
    appTitle = "FuelBot Lite La Paz",
    account = cuenta,
    server = "shinyapps.io",
    recordDir = ".",
    forceUpdate = TRUE,
    launch.browser = FALSE
  )
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  desplegar_shinyapps(dry_run = ("--dry-run" %in% args || "--check" %in% args))
}
