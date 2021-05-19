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
    continue when p3 is null;

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
--
-- The implementation could be significantly optimized to avoid `st_reverse`
-- and array reversals, trading for complexity in fix_gentle_inflections1.
create or replace function fix_gentle_inflections(INOUT bends geometry[]) as $$
declare
  len int4;
  bends1 geometry[];
begin
  len = array_length(bends, 1);

  bends = fix_gentle_inflections1(bends);
  for i in 1..len loop
    bends1[i] = st_reverse(bends[len-i+1]);
  end loop;
  bends1 = fix_gentle_inflections1(bends1);

  for i in 1..len loop
    bends[i] = st_reverse(bends1[len-i+1]);
  end loop;
end
$$ language plpgsql;

-- fix_gentle_inflections1 fixes gentle inflections of an array of lines in
-- one direction. This is an implementation detail of fix_gentle_inflections.
create or replace function fix_gentle_inflections1(INOUT bends geometry[]) as $$
declare
  pi real;
  small_angle real;
  ptail geometry; -- tail point of tail bend
  phead geometry[]; -- 3 tail points of head bend
  i int4; -- bends[i] is the current head
begin
  pi = radians(180);
  -- the threshold when the angle is still "small", so gentle inflections can
  -- be joined
  small_angle := radians(30);

  for i in 2..array_length(bends, 1) loop
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
    -- Assume this curve (figure `inflection-1`), going clockwise from A:
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
    select geom from st_dumppoints(bends[i-1])
      order by path[1] asc limit 1 into ptail;

    while true loop
      -- copy last 3 points of bends[i-1] (tail) to ptail
      select array(
        select geom from st_dumppoints(bends[i]) order by path[1] asc limit 3
      ) into phead;

      -- if the bend got too short, stop processing it
      exit when array_length(phead, 1) < 3;

      -- if inflection angle between ptail[1:3] "large", stop processing this bend
      exit when abs(st_angle(phead[1], phead[2], phead[3]) - pi) > small_angle;

      -- distance from head's first vertex should be larger than from second vertex
      exit when st_distance(ptail, phead[2]) < st_distance(ptail, phead[3]);

      -- detected a gentle inflection. Move head of the tail to the tail of head
      bends[i] = st_removepoint(bends[i], 0);
      bends[i-1] = st_addpoint(bends[i-1], phead[3]);
    end loop;

  end loop;
end
$$ language plpgsql;

-- self_crossing eliminates self-crossing from the bends, following the
-- article's section "Self-line Crossing When Cutting a Bend".
create or replace function self_crossing(INOUT bends geometry[]) as $$
declare
  i int4;
  j int4;
  pi real;
  angle real;
  p0 geometry;
  p1 geometry;
  p2 geometry;
  p3 geometry;
  s2 real;
  s3 real;
  bend geometry;
begin
  pi = radians(180);

  -- go through the bends and find one where sum of inflection angle is >180
  for i in 1..array_length(bends, 1) loop
    angle = 0;
    p1 = null;
    p2 = null;
    p3 = null;
    for p0 in (select geom from st_dumppoints(bends[i]) order by path[1] asc) loop
      p3 = p2;
      p2 = p1;
      p1 = p0;
      continue when p3 is null;

      angle = angle + abs(pi - st_angle(p1, p2, p3));
    end loop;

    continue when abs(angle) <= pi;

    -- sum of inflection angles for this bend is >180, so it may be self-crossing.
    -- now try to find another bend in this line that crosses this one.
    p0 = st_pointn(bends[i], 1);
    p1 = st_pointn(bends[i], -1);
    --this = st_makeline(st_pointn(bends[i], 1), st_pointn(bends[i], -1));

    -- go through each bend in this line, and see if has a potential to cross bends[i].
    -- optimization: we care only about bends which beginning and end start at different
    -- sides of the plane, separated by endpoints p0 and p1.
    for j in 1..array_length(bends, 1) loop
      continue when i = j;

      p2 = st_pointn(bends[j], 1);
      p3 = st_pointn(bends[j], -1);

      -- https://stackoverflow.com/questions/1560492
      s2 = (st_x(p0)-st_x(p1)*(st_y(p2)-st_y(p1))-(st_y(p0)-st_y(p1))*(st_x(p2)-st_x(p1)));
      s3 = (st_x(p0)-st_x(p1)*(st_y(p3)-st_y(p1))-(st_y(p0)-st_y(p1))*(st_x(p3)-st_x(p1)));
      continue when sign(s2) = sign(s3);

      -- bend j may be crossing bend i, and it has a chance to be "important" --
      -- p2 and p3 are in different sides of the plane as delimited by p0 and p1.
      -- now does it really cross the line (p0, p1)?

    end loop;

  end loop;

end
$$ language plpgsql;
