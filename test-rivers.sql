\set ON_ERROR_STOP on
SET plpgsql.extra_errors TO 'all';

-- This fails with real rivers since this:
-- commit dcf4c02307baeece51470a961a113a8fad68fad5
-- Merge: 44ee741 3638033
-- Author: Motiejus Jakštys <motiejus@uber.com>
-- Date:   Tue May 11 20:29:41 2021 +0300
-- 
--     Merge branch 'gdb10lt'
--     
--     This breaks "test-rivers" for Nemunas.
--
-- (adding GDB10LT data). The same rivers from OpenStreetMaps work.
-- There seems to be a bug in wm_exaggeration.

do $$
declare
  npoints bigint;
  secs bigint;
begin
  select * from ST_SimplifyWM_Estimate((select st_union(way) from wm_rivers)) into npoints, secs;
  raise notice 'Total points: %', npoints;
  raise notice 'Expected duration: %s (+-%s)', ceil(secs), floor(secs*.5);
end $$ language plpgsql;

delete from wm_debug where name in (select distinct name from wm_rivers);
delete from wm_demo where name in (select distinct name from wm_rivers);
insert into wm_demo (name, way) select name, ST_SimplifyWM(way, 75, null, name) from wm_rivers;
