\set ON_ERROR_STOP on
SET plpgsql.extra_errors TO 'all';

-- wm_bbox clips a geometry by a bounding box around a given object,
-- matching dimensions of A-class paper (1 by sqrt(2)).
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
end $$ language plpgsql;

-- wm_quadrant divides the given geometry to 4 rectangles
-- and returns the requested quadrant following cartesian
-- convention:
--  +----------+
--  | II  | I  |
--- +----------+
--  | III | IV |
--  +-----+----+
-- matching dimensions of A-class paper (1 by sqrt(2).
drop function if exists wm_quadrant;
create function wm_quadrant(
  geom geometry,
  quadrant integer
) returns geometry as $$
declare
  xmin float;
  xmax float;
  ymin float;
  ymax float;
begin
  xmin = st_xmin(geom);
  xmax = st_xmax(geom);
  ymin = st_ymin(geom);
  ymax = st_ymax(geom);

  if quadrant = 1 or quadrant = 2 then
    ymin = (ymin + ymax)/2;
  else
    ymax = (ymin + ymax)/2;
  end if;

  if quadrant = 2 or quadrant = 3 then
    xmax = (xmin + xmax)/2;
  else
    xmin = (xmin + xmax)/2;
  end if;

  return st_intersection(
    geom,
    st_makeenvelope(xmin, ymin, xmax, ymax, st_srid(geom))
  );
end $$ language plpgsql;


drop function if exists wm_salvisbbox;
create function wm_salvisbbox(
  geom geometry,
  scaledwidth float
) returns geometry as $$
declare
  ret geometry;
begin
  with multismall as (
    select st_intersection(
      st_union(geom),
      wm_bbox(
        st_closestpoint(
          (select way from wm_rivers where name='Šalčia'),
          (select way from wm_rivers where name='Visinčia')
        ),
        scaledwidth
      )
    ) ways
  )
  -- protecting against very small bends that were cut
  -- in the corner of the picture
  select st_union(a.geom)
  from st_dump((select ways from multismall)) a
  where st_length(a.geom) >= 100
  into ret;

  return ret;
end $$ language plpgsql;

delete from wm_debug where name like 'salvis%';
delete from wm_visuals where name like 'salvis%';
insert into wm_visuals(name, way) values
  ('salvis', (
    wm_salvisbbox(
      (select st_union(way) from wm_rivers where name in ('Šalčia', 'Visinčia')),
      :scaledwidth
    )
  )),
  ('salvis-gdr50', (
    wm_salvisbbox(
      (select st_union(way) from wm_rivers_50 where name in ('Šalčia', 'Visinčia')),
      :scaledwidth
    )
  )),
  ('salvis-gdr250', (
    wm_salvisbbox(
      (select st_union(way) from wm_rivers_250 where name in ('Šalčia', 'Visinčia')),
      :scaledwidth
    )
  ));

do $$
declare
  i integer;
  geom1 geometry;
  geom2 geometry;
  geom3 geometry;
begin
  foreach i in array array[16, 32, 64, 256] loop
    geom1 = st_simplify((select way from wm_visuals where name='salvis'), i);
    geom2 = st_simplifyvw((select way from wm_visuals where name='salvis'), i*i);
    insert into wm_visuals(name, way) values
      ('salvis-dp-'         || i, geom1),
      ('salvis-dp-chaikin-' || i, st_chaikinsmoothing(geom1, 5)),
      ('salvis-vw-'         || i, geom2),
      ('salvis-vw-chaikin-' || i, st_chaikinsmoothing(geom2, 5));
  end loop;

  -- more than 220 doesn't work, because there is an exaggerated bend near
  -- Šalčia-Visinčia crossing, and it "exaggerates" to the
  -- other river.
  foreach i in array array[75, 220] loop
    geom3 = st_simplifywm((select way from wm_visuals where name='salvis'), i, 50, 'salvis-wm-' || i);
    insert into wm_visuals(name, way) values
      ('salvis-wm-'          || i, geom3);
  end loop;
end $$ language plpgsql;
