\i wm.sql

drop table if exists wm_debug;
create table wm_debug(stage text, name text, gen bigint, nbend bigint, way geometry, props jsonb);

drop table if exists wm_demo;
create table wm_demo (name text, i bigint, way geometry);
insert into wm_demo (name, way) select name, ST_SimplifyWM(way, name) from agg_rivers;
