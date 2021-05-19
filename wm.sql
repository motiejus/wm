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
  --          p1___ ...
  --           /
  -- ... _____/
  --     p3   p2
  --
  -- When looping over the line, p1 will be head (lead) vertex, p2 will be the
  -- measured angle, and p3 will be trailing. The line that will be added to
  -- the bend will always be [p3,p2].
  -- So once the p1 becomes the last vertex, the loop terminates, and the
  -- [p2,p1] line will not have a chance to be added. So the loop adds the last
  -- vertex twice, so it has a chance to become p2, and be added to the bend.
  --
  for p in (
    (select geom from st_dumppoints(line) order by path[1] asc)
    union all
    (select geom from st_dumppoints(line) order by path[1] desc limit 1)
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

  -- the last line may be lost if there is no "final" inflection angle. Add it.
  if (select count(1) >= 2 from st_dumppoints(bend)) then
    bends = bends || bend;
  end if;
end
$$ language plpgsql;

-- fix_gentle_inflections moves bend endpoints following "Gentle Inflection at
-- End of a Bend" section.
--
-- The text does not specify how many vertices can be "adjusted"; it can
-- equally be one or many. This function is adjusting many, as long as the
-- commulative inflection angle small (see variable below).
create or replace function fix_gentle_inflections(INOUT bends geometry[]) as $$
declare
  small_angle real;
  phead geometry; -- head point of head bend
  ptail geometry[]; -- 3 head points of tail bend
  i int4; -- bends[i] is the current head
begin
  -- the threshold when the angle is still "small", so gentle inflections can
  -- be joined
  small_angle := radians(30);

  <<bend_loop>>
  for i in select generate_subscripts(bends, 1) loop
    if i = 1 then
      continue;
    end if;

    -- Predicate: two bends will always share an edge. Assuming (A,B,C,D,E,F)
    -- is a bend:
    --           C________D
    --           /        \
    -- \________/          \_______/
    -- A       B           E       F
    --
    -- Then edges (A,B) and (E,F) are shared with the neighboring bends.
    --
    --
    -- Assume this curve (figure `inflection-1`):
    --
    --    \______B
    --    A      `-------. C
    --                   |
    --    G___ F         |
    --    /   `-----.____+ D
    --              E
    --
    -- After processing the curve following the definition of a bend, the bend
    -- [A-E] would be detected. Assuming inflection point E and F are "small",
    -- the bend needs to be extended by two edges to [A,G].
    select geom from st_dumppoints(bends[i]) order by path[1] desc limit 1 into phead;
    while true loop
      -- copy last 3 points of bends[i-1] (tail) to ptail
      select array_agg(geom) from st_dumppoints(bends[i-1]) order by path[1] desc limit 3 into ptail;

      -- if inflection angle between ptail[1:3] "large", stop processing this bend
      if abs(st_angle(ptail[1], ptail[2], ptail[2], ptail[3]) - pi) > small_angle then
        exit bend_loop;
      end if;

      -- distance from last vertex should be larger than second-last vertex
      if st_distance(phead, ptail[2]) < st_distance(phead, ptail[3]) then
        exit bend_loop;
      end if;

      -- detected a gentle inflection. Move head of the tail to the tail of head
      bends[i] = st_addpoint(bends[i], ptail[3]);
      bends[i-1] = st_removepoint(bends[i-1], st_npoints(bends[i-1])-1);
    end loop;

  end loop;
end
$$ language plpgsql;
