\i wm.sql

drop table if exists debug_wm;
create table debug_wm(name text, way geometry, props json);

drop table if exists demo_wm;
create table demo_wm (name text, i bigint, way geometry);
insert into demo_wm (name, way) select name, ST_SimplifyWM(way, true) from agg_rivers;
