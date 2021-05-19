\i wm.sql

drop table if exists wm_debug;
create table wm_debug(stage text, name text, gen bigint, nbend bigint, way geometry, props jsonb);

do $$
declare
  npoints bigint;
  secs bigint;
begin
  select * from ST_SimplifyWM_Estimate((select st_union(way) from agg_rivers)) into npoints, secs;
  raise notice 'Total points: %', npoints;
  raise notice 'Expected duration: %s (+-%s), depending on bend complexity', ceil(secs), floor(secs*.5);
end $$ language plpgsql;

drop table if exists wm_demo;
create table wm_demo (name text, i bigint, way geometry);
insert into wm_demo (name, way) select name, ST_SimplifyWM(way, name) from agg_rivers;
