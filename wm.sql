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

  for p in (select (dp).geom from st_dumppoints(line) as dp) loop
    p3 = p2;
    p2 = p1;
    p1 = p;
    if p3 is null then
      continue;
    end if;
    cur_sign = sign(pi - st_angle(p1, p2, p2, p3));

    bend = st_linemerge(st_union(bend, st_makeline(p3, p2)));

    if prev_sign + cur_sign = 0 then
      if bend is not null then
        bends = bends || bend;
      end if;
      bend = st_makeline(p3, p2);
    end if;
    prev_sign = cur_sign;
  end loop;

  -- the last bend may be lost if there is no "final" inflection angle.
  -- to avoid that, return the last bend if the last accumulation has >3
  -- vertices.
  if (select count(1) from ((select st_dumppoints(bend) as a)) b) >= 3 then
    bends = bends || bend;
  end if;
end
$$ language plpgsql;


-- fix_gentle_inflections moves bend endpoints in case of gentle inflections
create or replace function fix_gentle_inflections(line geometry) returns table(bend geometry) as $$
begin
end
$$ language plpgsql;
