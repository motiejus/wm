\set ON_ERROR_STOP on
SET plpgsql.extra_errors TO 'all';

drop function if exists detect_bends;
-- detect_bends detects bends using the inflection angles. It does not do corrections.
create or replace function detect_bends(line geometry, OUT bends geometry[]) as $$
declare
  pi real;
  p geometry;
  p1 geometry;
  p2 geometry;
  p3 geometry;
  bend geometry;
  prev_sign int4;
  cur_sign int4;
begin
  pi = radians(180);

  -- the last vertex is iterated over twice, because the algorithm uses 3 vertices
  -- to calculate the angle between them.
  --
  -- Given 3 vertices p1, p2, p3:
  --
  --         p1___ ...
  --          /
  -- ..._____/
  --    p3   p2
  --
  -- This loop will use p1 as the head vertex, p2 will be the measured angle,
  -- and p3 will be trailing. The line that will be added to the bend will
  -- always be [p3,p2].
  -- So once the p1 becomes the last vertex, the loop terminates, and the
  -- [p2,p1] line will not have a chance to be added. So the loop adds the last
  -- vertex twice, so it has a chance to become p2, and be added to the bend.
  --
  for p in (
    (select (dp).geom from st_dumppoints(line) as dp order by (dp).path[1] asc)
    union all
    (select (dp).geom from st_dumppoints(line) as dp order by (dp).path[1] desc limit 1)
  ) loop
    p3 = p2;
    p2 = p1;
    p1 = p;
    if p3 is null then
      continue;
    end if;
    cur_sign = sign(pi - st_angle(p1, p2, p2, p3));

    if bend is null then
      bend = st_makeline(p3, p2);
    else
      bend = st_linemerge(st_union(bend, st_makeline(p3, p2)));
    end if;

    if prev_sign + cur_sign = 0 then
      if bend is not null then
        bends = bends || bend;
      end if;
      bend = st_makeline(p3, p2);
    end if;
    prev_sign = cur_sign;
  end loop;

  -- the last bend may be lost if there is no "final" inflection angle. Add it.
  if (select count(1) from ((select st_dumppoints(bend) as a)) b) >= 2 then
    bends = bends || bend;
  end if;
end
$$ language plpgsql;

-- fix_gentle_inflections moves bend endpoints following "Gentle Inflection at
-- End of a Bend" section.
create or replace function fix_gentle_inflections(INOUT bends geometry[]) as $$
begin
end
$$ language plpgsql;
