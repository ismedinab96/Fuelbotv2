-- FuelBot Lite · Vistas de consulta + rol de SOLO LECTURA para la app y el agente
-- Ejecutar DESPUÉS de 01_esquema.sql. Cambia la contraseña de agente_ro antes de ejecutar.

create or replace view fuel.v_productos as
select * from (values
  (0::smallint, 'Gasolina Especial'),
  (1::smallint, 'Diésel Oil'),
  (2::smallint, 'Gasolina Premium'),
  (3::smallint, 'Diésel ULS')
) as t(id_producto, producto);

-- ciudad_segun_direccion es APROXIMADA: sale del texto de la dirección
create or replace view fuel.v_estaciones as
select e.id_eess, e.nombre, e.direccion, e.zona, e.lat, e.lng,
       case when upper(e.direccion) like 'EL ALTO%'  then 'El Alto'
            when upper(e.direccion) like 'LA PAZ%'   then 'La Paz'
            else null end as ciudad_segun_direccion
from fuel.estaciones e;

-- Último dato conocido por estación y producto.
-- tipo_dato = 'saldo_reportado_ANH': es lo que reporta el portal, NO una garantía de disponibilidad.
create or replace view fuel.v_saldo_actual as
select distinct on (s.id_eess, s.id_producto)
       s.id_eess, e.nombre, e.direccion, e.lat, e.lng,
       s.id_producto, p.producto,
       s.saldo_litros, s.saldo_estado, s.con_venta, s.despacho_en_curso,
       s.fecha_ultima_venta,
       s.fecha_actualizacion_sistema            as fecha_reporte,
       s.fecha_actualizacion                    as fecha_captura,
       round((extract(epoch from ((now() at time zone 'America/La_Paz') - s.fecha_actualizacion_sistema)) / 3600)::numeric, 1)
                                                as antiguedad_reporte_horas,
       'saldo_reportado_ANH'::text              as tipo_dato,
       'ANH (abastecimiento.prod.anh.gob.bo)'::text as fuente
from fuel.saldos s
join fuel.estaciones e using (id_eess)
join fuel.v_productos p using (id_producto)
order by s.id_eess, s.id_producto, s.fecha_actualizacion desc;

-- Histórico completo de saldos (úsese siempre con filtros de fecha y LIMIT)
create or replace view fuel.v_saldo_historico as
select s.fecha_actualizacion as fecha_captura,
       s.fecha_actualizacion_sistema as fecha_reporte,
       s.id_eess, e.nombre, p.producto,
       s.saldo_litros, s.saldo_estado, s.con_venta, s.despacho_en_curso,
       'saldo_reportado_ANH'::text as tipo_dato
from fuel.saldos s
join fuel.estaciones e using (id_eess)
join fuel.v_productos p using (id_producto);

create or replace view fuel.v_ypfb_despachos as
select fecha_captura, fecha_datos, distrito_codigo, distrito_nombre, producto_general,
       producto_despachado, familia, cliente, estacion, placa_despacho,
       cantidad_despachada as litros_despachados, fecha_despacho_efectivo,
       fecha_despacho_efectivo_hora, despacho_confirmado, ambito,
       'despacho_confirmado_YPFB'::text as tipo_dato
from fuel.ypfb_despachos;

create or replace view fuel.v_ypfb_programacion as
select fecha_captura, fecha_datos, distrito_codigo, distrito_nombre, producto_general,
       producto, familia, cliente, volumen_programado as litros_programados, canal, atendida,
       'programacion_YPFB'::text as tipo_dato
from fuel.ypfb_programacion;

create or replace view fuel.v_ypfb_resumen as
select fecha_captura, fecha_datos, distrito_codigo, distrito_nombre, producto_general,
       litros_programados, litros_despachados, litros_pendientes_confirmacion,
       'resumen_YPFB'::text as tipo_dato
from fuel.ypfb_resumen;

-- Qué fuentes existen y cuándo fue la última captura exitosa de cada una
create or replace view fuel.v_fuentes as
select f.fuente, f.descripcion, f.url, f.tipo_dato,
       (select max(fin) from fuel.ingesta_log l where l.fuente = f.clave and l.estado = 'ok') as ultima_ingesta_ok
from (values
  ('anh',  'ANH',  'Saldo por estación y producto (litros y estado bajo/medio/alto)', 'https://abastecimiento.prod.anh.gob.bo', 'saldo_reportado_ANH'),
  ('ypfb', 'YPFB', 'Despachos de cisternas, programación y resumen por distrito comercial', 'https://consulta.ypfb.gob.bo', 'despacho_confirmado_YPFB / programacion_YPFB')
) as f(clave, fuente, descripcion, url, tipo_dato);

-- Cobertura temporal disponible
create or replace view fuel.v_cobertura as
select 'saldos'::text as conjunto, min(fecha_actualizacion) as desde, max(fecha_actualizacion) as hasta, count(*) as filas from fuel.saldos
union all select 'ypfb_despachos', min(fecha_datos)::timestamp, max(fecha_datos)::timestamp, count(*) from fuel.ypfb_despachos
union all select 'ypfb_programacion', min(fecha_datos)::timestamp, max(fecha_datos)::timestamp, count(*) from fuel.ypfb_programacion;

-- ── Rol de solo lectura ────────────────────────────────────────────────────
do $$
begin
  if not exists (select from pg_roles where rolname = 'agente_ro') then
    create role agente_ro login password 'GKefgNR4kSx1yh7I' nosuperuser nocreatedb nocreaterole noinherit;
  end if;
end $$;

alter role agente_ro set statement_timeout = '8s';
alter role agente_ro set default_transaction_read_only = on;
alter role agente_ro set search_path = fuel;

grant usage on schema fuel to agente_ro;
revoke all on all tables in schema fuel from agente_ro;
grant select on fuel.v_productos, fuel.v_estaciones, fuel.v_saldo_actual, fuel.v_saldo_historico,
                fuel.v_ypfb_despachos, fuel.v_ypfb_programacion, fuel.v_ypfb_resumen,
                fuel.v_fuentes, fuel.v_cobertura
      to agente_ro;
