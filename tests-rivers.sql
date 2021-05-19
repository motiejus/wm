\i wm.sql

insert into wm_visuals(name, way) values('salcia-visincia',
  st_closestpoint(
    (select way from wm_rivers where name='Šalčia'),
    (select way from wm_rivers where name='Visinčia')
  )
);

insert into wm_visuals(name, way) values('nemunas-merkys',
  st_closestpoint(
    (select way from wm_rivers where name='Nemunas'),
    (select way from wm_rivers where name='Merkys')
  )
);

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
insert into wm_demo (name, way) select name, ST_SimplifyWM(way, name) from wm_rivers;
