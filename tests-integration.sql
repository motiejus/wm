\i wm.sql

drop table if exists debug_wm;
create table debug_wm(stage text, name text, gen bigint, nbend bigint, way geometry, props json);

drop table if exists demo_wm;
create table demo_wm (name text, i bigint, way geometry);
insert into demo_wm (name, way) select name, ST_SimplifyWM(way, name) from agg_rivers;
