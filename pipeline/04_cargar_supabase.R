# FuelBot Lite · Carga idempotente a Supabase (Postgres): se puede repetir sin duplicar filas.
# Estrategia: tabla temporal con todo en texto -> INSERT ... SELECT con conversión de tipos -> ON CONFLICT.

TIPOS <- list(
  estaciones = c(id_eess = "numeric::integer", nombre = "text", direccion = "text", zona = "text",
                 departamento_id = "numeric::smallint", lat = "double precision", lng = "double precision"),
  saldos = c(fecha_actualizacion = "timestamp", id_eess = "numeric::integer", id_producto = "numeric::smallint",
             fecha_actualizacion_sistema = "timestamp", saldo_litros = "numeric", saldo_estado = "text", con_venta = "boolean",
             fecha_ultima_venta = "timestamp", despacho_en_curso = "boolean", fecha_hora_despacho = "timestamp", seguimiento_id = "text"),
  ypfb_despachos = c(clave = "text", fecha_captura = "timestamp", fecha_datos = "date", distrito_codigo = "text", distrito_nombre = "text",
                     producto_general = "text", producto_despachado = "text", familia = "text", cliente = "text", estacion = "text",
                     placa_despacho = "text", cantidad_despachada = "numeric", unidad = "text", fecha_despacho_programado = "date",
                     fecha_despacho_efectivo = "date", fecha_despacho_efectivo_hora = "timestamptz", despacho_confirmado = "boolean", ambito = "text"),
  ypfb_programacion = c(clave = "text", fecha_captura = "timestamp", fecha_datos = "date", distrito_codigo = "text", distrito_nombre = "text",
                        producto_general = "text", producto = "text", familia = "text", cliente = "text", volumen_programado = "numeric",
                        canal = "text", atendida = "boolean"),
  ypfb_resumen = c(fecha_captura = "timestamp", fecha_datos = "date", distrito_codigo = "text", distrito_nombre = "text", producto_general = "text",
                   litros_programados = "numeric", litros_despachados = "numeric", litros_pendientes_confirmacion = "numeric")
)

# SQL de carga (separado para poder probarlo): tabla temporal en texto -> INSERT ... SELECT con tipos
sql_carga <- function(tabla, clave, actualizar = character(0), tmp = paste0("tmp_", tabla)) {
  tipos <- TIPOS[[tabla]]; cols <- names(tipos)
  sel <- paste0("nullif(\"", cols, "\", '')::", tipos, collapse = ", ")
  accion <- if (length(actualizar)) paste0("do update set ", paste0(actualizar, " = excluded.", actualizar, collapse = ", ")) else "do nothing"
  paste0("insert into fuel.", tabla, " (", paste(cols, collapse = ", "), ") select ", sel,
         " from ", tmp, " on conflict (", paste(clave, collapse = ", "), ") ", accion)
}

cargar_tabla <- function(con, df, tabla, clave, actualizar = character(0), lote = 20000) {
  cols <- names(TIPOS[[tabla]])
  for (c in setdiff(cols, names(df))) df[[c]] <- NA_character_
  df <- df[, cols, drop = FALSE]
  df[] <- lapply(df, as.character)
  df <- df[!duplicated(df[, clave, drop = FALSE], fromLast = TRUE), , drop = FALSE]
  if (!nrow(df)) return(0L)
  tmp <- paste0("tmp_", tabla)
  sql <- sql_carga(tabla, clave, actualizar, tmp)
  total <- 0L
  for (idx in split(seq_len(nrow(df)), ceiling(seq_len(nrow(df)) / lote))) {
    n <- DBI::dbWithTransaction(con, {
      DBI::dbWriteTable(con, tmp, df[idx, , drop = FALSE], temporary = TRUE, overwrite = TRUE, row.names = FALSE)
      k <- DBI::dbExecute(con, sql)
      DBI::dbExecute(con, paste0("drop table if exists ", tmp))
      k
    })
    total <- total + n
  }
  total
}

cargar_saldos <- function(con, res) {
  est_cols <- setdiff(names(TIPOS$estaciones), "id_eess")
  cargar_tabla(con, res$estaciones, "estaciones", "id_eess", actualizar = est_cols)
  cargar_tabla(con, res$saldos, "saldos", c("fecha_actualizacion", "id_eess", "id_producto"))
}

cargar_ypfb <- function(con, res) {
  n1 <- cargar_tabla(con, res$despachos, "ypfb_despachos", "clave")
  n2 <- cargar_tabla(con, res$programacion, "ypfb_programacion", "clave", actualizar = c("fecha_captura", "atendida", "volumen_programado"))
  n3 <- cargar_tabla(con, res$resumen, "ypfb_resumen", c("fecha_captura", "distrito_codigo", "producto_general"))
  n1 + n2 + n3
}

registrar_log <- function(con, fuente, inicio, filas, estado, mensaje = NA_character_) {
  DBI::dbExecute(con, "insert into fuel.ingesta_log (fuente, inicio, fin, filas, estado, mensaje) values ($1, $2, now(), $3, $4, $5)",
                 params = list(fuente, format(inicio, "%Y-%m-%d %H:%M:%S%z"), as.integer(filas), estado, mensaje))
}
