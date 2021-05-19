\i wm.sql

drop table if exists agg_rivers_wm;
create table agg_rivers_wm (name text, way geometry);
insert into agg_rivers_wm (name, way) select name, ST_SimplifyWM_DEBUG(way) from agg_rivers where name='Visinčia';
