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
