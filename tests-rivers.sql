\i wm.sql

-- wm_envelope clips a geometry by a bounding box around a given object,
-- matching dimensions of A-class paper (1 by sqrt(2).
drop function if exists wm_bbox;
create function wm_bbox(
  center geometry,
  scaledwidth float
) returns geometry as $$
declare
  halfX float;
  halfY float;
begin
  halfX = scaledwidth / 2;
  halfY = halfX * sqrt(2);
  return st_envelope(
    st_union(
      st_translate(center, halfX, halfY),
      st_translate(center, -halfX, -halfY)
    )
  );
end
$$ language plpgsql;

delete from wm_visuals where name like 'salvis%';
insert into wm_visuals(name, way) values('salvis', (
    select st_intersection(
      (select st_union(way) from wm_rivers where name in ('Šalčia', 'Visinčia')),
      wm_bbox(
        st_closestpoint(
          (select way from wm_rivers where name='Šalčia'),
          (select way from wm_rivers where name='Visinčia')
        ),
        :scaledwidth
      )
    )
));

do $$
declare
  i integer;
  geom1 geometry;
  geom2 geometry;
begin
  foreach i in array array[16, 64, 256] loop
    geom1 = st_simplify((select way from wm_visuals where name='salvis'), i);
    geom2 = st_simplifyvw((select way from wm_visuals where name='salvis'), i*i);
    insert into wm_visuals(name, way) values
      ('salvis-douglas-'     || i, geom1),
      ('salvis-douglas-'     || i || '-chaikin', st_chaikinsmoothing(geom1, 5)),
      ('salvis-visvalingam-' || i, geom2),
      ('salvis-visvalingam-' || i || '-chaikin', st_chaikinsmoothing(geom2, 5));
  end loop;
end $$ language plpgsql;

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
--insert into wm_demo (name, way) select name, ST_SimplifyWM(way, name) from wm_rivers;
