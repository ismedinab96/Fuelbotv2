# FuelBot Lite · Orquestador. Uso (desde la carpeta del proyecto):
#   Rscript pipeline/run_pipeline.R anh           # captura actual del portal ANH (solo La Paz)
#   Rscript pipeline/run_pipeline.R ypfb          # captura actual de YPFB
#   Rscript pipeline/run_pipeline.R todo          # anh + ypfb   (lo que corre el cron)
#   Rscript pipeline/run_pipeline.R backfill      # historial desde el repo sociedatos/bo-combustible
#   Rscript pipeline/run_pipeline.R backfill-local RUTA/bo-combustible   # igual, desde un clon local
args <- commandArgs(trailingOnly = TRUE)
modo <- if (length(args)) args[1] else "todo"
local_dir <- if (length(args) >= 2) args[2] else NULL

dir_pipeline <- "pipeline"
for (f in c("00_config.R", "01_extraer_anh.R", "02_extraer_ypfb.R", "03_backfill_repo.R", "04_cargar_supabase.R"))
  source(file.path(dir_pipeline, f), encoding = "UTF-8")

fallos <- 0
correr <- function(fuente, extraer, cargar) {
  t0 <- Sys.time(); con <- con_escritura(); on.exit(DBI::dbDisconnect(con))
  tryCatch({
    res <- extraer()
    for (a in res$advertencias) message("  [aviso] ", a)
    filas <- cargar(con, res)
    registrar_log(con, fuente, t0, filas, "ok", if (length(res$advertencias)) paste(res$advertencias, collapse = " | ") else NA_character_)
    message(sprintf("[ok] %s: %d filas nuevas o actualizadas", fuente, filas))
  }, error = function(e) {
    fallos <<- fallos + 1
    message("[ERROR] ", fuente, ": ", conditionMessage(e))
    try(registrar_log(con, fuente, t0, 0, "error", conditionMessage(e)), silent = TRUE)
  })
}

if (modo %in% c("anh", "todo"))  correr("anh",  extraer_anh,  cargar_saldos)
if (modo %in% c("ypfb", "todo")) correr("ypfb", extraer_ypfb, cargar_ypfb)
if (modo %in% c("backfill", "backfill-local")) {
  correr("backfill_anh",  function() backfill_anh(local_dir),  cargar_saldos)
  correr("backfill_ypfb", function() backfill_ypfb(local_dir), cargar_ypfb)
}
if (!modo %in% c("anh", "ypfb", "todo", "backfill", "backfill-local")) stop("Modo desconocido: ", modo)
if (fallos > 0) quit(status = 1)
