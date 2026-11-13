-- FuelBot Lite · Esquema para Supabase (PostgreSQL)
-- Ejecutar en Supabase > SQL Editor. Es idempotente (se puede repetir).
-- Todas las horas se guardan en hora de Bolivia (UTC-4) como "timestamp" sin zona,
-- igual que el repositorio sociedatos/bo-combustible.

create schema if not exists fuel;   -- esquema propio: NO queda expuesto por la API REST de Supabase

create table if not exists fuel.estaciones (
  id_eess          integer primary key,
  nombre           text,
  direccion        text,
  zona             text,
  departamento_id  smallint,
  lat              double precision,
  lng              double precision,
  actualizado_en   timestamptz not null default now()
);

-- Una fila por captura (snapshot) x estación x producto (portal ANH)
create table if not exists fuel.saldos (
  fecha_actualizacion         timestamp not null,   -- cuándo capturamos el dato
  id_eess                     integer   not null references fuel.estaciones(id_eess),
  id_producto                 smallint  not null,   -- 0 Gasolina Especial, 1 Diésel Oil, 2 Gasolina Premium, 3 Diésel ULS
  fecha_actualizacion_sistema timestamp,            -- cuándo lo reportó la estación/ANH
  saldo_litros                numeric,
  saldo_estado                text,                 -- bajo | medio | alto (categoría reportada por ANH)
  con_venta                   boolean,
  fecha_ultima_venta          timestamp,
  despacho_en_curso           boolean,
  fecha_hora_despacho         timestamp,
  seguimiento_id              text,
  primary key (fecha_actualizacion, id_eess, id_producto)
);
create index if not exists saldos_estacion_idx on fuel.saldos (id_eess, id_producto, fecha_actualizacion desc);

-- YPFB: despachos de cisternas (clave = hash calculado en R)
create table if not exists fuel.ypfb_despachos (
  clave                         text primary key,
  fecha_captura                 timestamp not null,
  fecha_datos                   date,
  distrito_codigo               text,
  distrito_nombre               text,
  producto_general              text,
  producto_despachado           text,
  familia                       text,
  cliente                       text,
  estacion                      text,
  placa_despacho                text,
  cantidad_despachada           numeric,
  unidad                        text,
  fecha_despacho_programado     date,
  fecha_despacho_efectivo       date,
  fecha_despacho_efectivo_hora  timestamptz,
  despacho_confirmado           boolean,
  ambito                        text
);
create index if not exists ypfb_desp_fecha_idx on fuel.ypfb_despachos (fecha_despacho_efectivo);

-- YPFB: programación (se actualiza "atendida" durante el día)
create table if not exists fuel.ypfb_programacion (
  clave               text primary key,
  fecha_captura       timestamp not null,
  fecha_datos         date,
  distrito_codigo     text,
  distrito_nombre     text,
  producto_general    text,
  producto            text,
  familia             text,
  cliente             text,
  volumen_programado  numeric,
  canal               text,
  atendida            boolean
);
create index if not exists ypfb_prog_fecha_idx on fuel.ypfb_programacion (fecha_datos);

-- YPFB: resumen por distrito (historial de capturas)
create table if not exists fuel.ypfb_resumen (
  fecha_captura                   timestamp not null,
  fecha_datos                     date,
  distrito_codigo                 text not null,
  distrito_nombre                 text,
  producto_general                text not null,
  litros_programados              numeric,
  litros_despachados              numeric,
  litros_pendientes_confirmacion  numeric,
  primary key (fecha_captura, distrito_codigo, producto_general)
);

-- Bitácora de cada corrida del pipeline (trazabilidad)
create table if not exists fuel.ingesta_log (
  id          bigint generated always as identity primary key,
  fuente      text not null,        -- anh | ypfb | backfill_anh | backfill_ypfb
  inicio      timestamptz not null default now(),
  fin         timestamptz,
  filas       integer,
  estado      text,                 -- ok | error
  mensaje     text
);

-- Seguridad: nadie salvo el dueño toca las tablas
revoke all on all tables in schema fuel from public;
