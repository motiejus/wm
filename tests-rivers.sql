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


-- wm_envelope clips a geometry by a bounding box around a given object,
-- matching dimensions of A-class paper (1 by sqrt(2).
drop function if exists wm_bbox;
create function wm_bbox(
  center text,
  projection_scale integer,
  projection_width_cm float
) returns geometry as $$
declare
  gcenter geometry;
  halfX float;
  halfY float;
begin
  halfX = projection_scale * projection_width_cm / 2 / 100;
  halfY = halfX * sqrt(2);
  select way from wm_visuals where name=center into gcenter;
  if gcenter is null then
    raise 'center % not found', center;
  end if;

  return st_envelope(
    st_union(
      st_translate(gcenter, halfX, halfY),
      st_translate(gcenter, -halfX, -halfY)
    )
  );
end
$$ language plpgsql;

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
