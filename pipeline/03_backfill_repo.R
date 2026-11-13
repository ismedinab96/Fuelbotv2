# FuelBot Lite · Historial inicial desde el repo público sociedatos/bo-combustible
# Descarga los CSV semanales ya publicados (los actualiza su bot) y filtra solo La Paz.
# Útil para tener datos desde el día 1 y como respaldo si el portal bloquea tu extracción directa.

listar_csv_repo <- function(carpeta, origen_local = NULL) {
  if (!is.null(origen_local)) return(list.files(file.path(origen_local, carpeta), pattern = "\\.csv$", full.names = FALSE))
  js <- jsonlite::fromJSON(pedir(paste0(CFG$repo_api, "/", carpeta), list(ref = "main")), simplifyVector = FALSE)
  nombres <- vapply(js, function(x) x$name, "")
  nombres[grepl("\\.csv$", nombres)]
}

leer_csv_repo <- function(ruta, origen_local = NULL) {
  f <- if (!is.null(origen_local)) file.path(origen_local, ruta) else pedir(paste0(CFG$repo_raw, "/", ruta), destino = tempfile(fileext = ".csv"))
  readr::read_csv(f, col_types = readr::cols(.default = "c"), progress = FALSE, show_col_types = FALSE)
}

backfill_anh <- function(origen_local = NULL, ultimas = Inf) {
  archivos <- listar_csv_repo("data_abastecimiento", origen_local)
  archivos <- tail(sort(archivos), ultimas)
  if (!length(archivos)) stop("No encontré CSV en data_abastecimiento", call. = FALSE)
  df <- map_dfr(archivos, function(a) { message("  leyendo data_abastecimiento/", a); leer_csv_repo(paste0("data_abastecimiento/", a), origen_local) })
  normalizar_saldos(df, captura = NULL)
}

backfill_ypfb <- function(origen_local = NULL, ultimas = Inf) {
  leer_seccion <- function(seccion) {
    archivos <- tail(sort(listar_csv_repo(paste0("data_ypfb/", seccion), origen_local)), ultimas)
    map_dfr(archivos, function(a) { message("  leyendo data_ypfb/", seccion, "/", a); leer_csv_repo(paste0("data_ypfb/", seccion, "/", a), origen_local) })
  }
  list(despachos = normalizar_despachos(leer_seccion("despachos")),
       programacion = normalizar_programacion(leer_seccion("programacion")),
       resumen = normalizar_resumen(leer_seccion("resumen")),
       advertencias = character())
}
