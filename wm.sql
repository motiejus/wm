\set ON_ERROR_STOP on
SET plpgsql.extra_errors TO 'all';

-- detect_bends detects bends using the inflection angles. No corrections.
drop function if exists detect_bends;
create function detect_bends(
  line geometry,
  dbgname text default null,
  dbgstagenum integer default null,
  OUT bends geometry[]
) as $$
declare
  pi constant real default radians(180);
  p geometry;
  p1 geometry;
  p2 geometry;
  p3 geometry;
  bend geometry;
  prev_sign int4;
  cur_sign int4;
  l_type text;
begin
  l_type = st_geometrytype(line);
  if l_type != 'ST_LineString' then
    raise 'This function works with ST_LineString, got %', l_type;
  end if;

  -- The last vertex is iterated over twice, because the algorithm uses 3
  -- vertices to calculate the angle between them.
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
  for p in
      (select geom from st_dumppoints(line) order by path[1] asc)
      union all
      (select geom from st_dumppoints(line) order by path[1] desc limit 1)
     loop
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

  if dbgname is not null then
    for i in 1..array_length(bends, 1) loop
      insert into wm_debug(stage, name, gen, nbend, way) values(
        'bbends',
        dbgname,
        dbgstagenum,
        i,
        bends[i]
      );
      insert into wm_debug(stage, name, gen, nbend, way) values(
        'bbends-polygon',
        dbgname,
        dbgstagenum,
        i,
        st_makepolygon(st_addpoint(bends[i], st_startpoint(bends[i])))
      );
    end loop;
  end if;
end
$$ language plpgsql;

-- fix_gentle_inflections moves bend endpoints following "Gentle Inflection at
-- End of a Bend" section.
--
-- The text does not specify how many vertices can be "adjusted"; it can
-- equally be one or many. This function is adjusting many, as long as the
-- cumulative inflection angle small (see variable below).
--
-- The implementation could be significantly optimized to avoid `st_reverse`
-- and array reversals, trading for complexity in fix_gentle_inflections1.
create or replace function fix_gentle_inflections(
  INOUT bends geometry[],
  dbgname text default null,
  dbgstagenum integer default null
) as $$
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

  if dbgname is not null then
    for i in 1..array_length(bends, 1) loop
      insert into wm_debug(stage, name, gen, nbend, way) values(
        'cinflections',
        dbgname,
        dbgstagenum,
        i,
        bends[i]
      );
      insert into wm_debug(stage, name, gen, nbend, way) values(
        'cinflections-polygon',
        dbgname,
        dbgstagenum,
        i,
        st_makepolygon(st_addpoint(bends[i], st_startpoint(bends[i])))
      );
    end loop;
  end if;
end
$$ language plpgsql;

-- fix_gentle_inflections1 fixes gentle inflections of an array of lines in
-- one direction. This is an implementation detail of fix_gentle_inflections.
drop function if exists fix_gentle_inflections1;
create function fix_gentle_inflections1(INOUT bends geometry[]) as $$
declare
  pi constant real default radians(180);
  -- the threshold when the angle is still "small", so gentle inflections can
  -- be joined
  small_angle constant real default radians(45);
  ptail geometry; -- tail point of tail bend
  phead geometry[]; -- 3 tail points of head bend
  i int4; -- bends[i] is the current head
begin
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

      -- inflection angle between ptail[1:3] is "large", stop processing
      exit when abs(st_angle(phead[1], phead[2], phead[3]) - pi) > small_angle;

      -- distance from head's 1st vertex should be larger than from 2nd vertex
      exit when st_distance(ptail, phead[2]) < st_distance(ptail, phead[3]);

      -- Detected a gentle inflection.
      -- Move head of the tail to the tail of head
      bends[i] = st_removepoint(bends[i], 0);
      bends[i-1] = st_addpoint(bends[i-1], phead[3]);
    end loop;

  end loop;
end
$$ language plpgsql;

-- if_selfcross returns whether baseline of bendi crosses bendj.
-- If it doesn't, returns a null geometry.
-- Otherwise, it will return the baseline split into a few parts where it
-- crosses bendj.
drop function if exists if_selfcross;
create function if_selfcross(
  bendi geometry,
  bendj geometry
) returns geometry as $$
declare
  a geometry;
  b geometry;
  multi geometry;
begin
  a = st_pointn(bendi, 1);
  b = st_pointn(bendi, -1);
  multi = st_split(bendj, st_makeline(a, b));

  if st_numgeometries(multi) = 1 then
    return null;
  end if;

  if st_numgeometries(multi) = 2 and
    (st_contains(bendj, a) or st_contains(bendj, b)) then
    return null;
  end if;

  return multi;
end
$$ language plpgsql;


-- self_crossing eliminates self-crossing from the bends, following the
-- article's section "Self-line Crossing When Cutting a Bend".
drop function if exists self_crossing;
create function self_crossing(
  INOUT bends geometry[],
  OUT mutated boolean
) as $$
declare
  pi constant real default radians(180);
  i int4;
  j int4;
  multi geometry;
begin
  mutated = false;
  <<bendloop>>
  for i in 1..array_length(bends, 1) loop
    continue when abs(inflection_angle(bends[i])) <= pi;
    -- sum of inflection angles for this bend is >180, so it may be
    -- self-crossing. now try to find another bend in this line that
    -- crosses an imaginary line of end-vertices

    -- Go through each bend in the given line, and see if has a potential to
    -- cross bends[i]. The line-cut process is different when i<j and i>j;
    -- therefore there are two loops, one for each case.
    for j in 1..i-1 loop
      multi = if_selfcross(bends[i], bends[j]);
      continue when multi is null;
      mutated = true;

      -- remove first vertex of the following bend, because the last
      -- segment is always duplicated with the i'th bend.
      bends[i+1] = st_removepoint(bends[i+1], 0);
      bends[j] = st_geometryn(multi, 1);
      bends[j] = st_setpoint(
        bends[j],
        st_npoints(bends[j])-1,
        st_pointn(bends[i], st_npoints(bends[i]))
      );
      bends = bends[1:j] || bends[i+1:];
      continue bendloop;
    end loop;

    for j in reverse array_length(bends, 1)..i+1 loop
      multi = if_selfcross(bends[i], bends[j]);
      continue when multi is null;
      mutated = true;

      -- remove last vertex of the previous bend, because the last
      -- segment is duplicated with the i'th bend.
      bends[i-1] = st_removepoint(bends[i-1], st_npoints(bends[i-1])-1);
      bends[i] = st_makeline(
        st_pointn(bends[i], 1),
        st_removepoint(st_geometryn(multi, st_numgeometries(multi)), 0)
      );
      bends = bends[1:i] || bends[j+1:];
      continue bendloop;
    end loop;
  end loop;
end
$$ language plpgsql;

drop function if exists inflection_angle;
create function inflection_angle (IN bend geometry, OUT angle real) as $$
declare
  pi constant real default radians(180);
  p0 geometry;
  p1 geometry;
  p2 geometry;
  p3 geometry;
begin
  angle = 0;
  for p0 in select geom from st_dumppoints(bend) order by path[1] asc loop
    p3 = p2;
    p2 = p1;
    p1 = p0;
    continue when p3 is null;
    angle = angle + abs(pi - st_angle(p1, p2, p3));
  end loop;
end
$$ language plpgsql;


drop function if exists bend_attrs;
drop function if exists isolated_bends;
drop type if exists t_bend_attrs;
create type t_bend_attrs as (
  bend geometry,
  area real,
  cmp real,
  adjsize real,
  baselinelength real,
  curvature real,
  isolated boolean
);
create function bend_attrs(
  bends geometry[],
  dbgname text default null
) returns setof t_bend_attrs as $$
declare
  fourpi constant real default 4*radians(180);
  i int4;
  polygon geometry;
  bend geometry;
  res t_bend_attrs;
begin
  for i in 1..array_length(bends, 1) loop
    bend = bends[i];
    res = null;
    res.bend = bend;
    res.area = 0;
    res.cmp = 0;
    res.adjsize = 0;
    res.baselinelength = st_distance(st_startpoint(bend), st_endpoint(bend));
    res.curvature = inflection_angle(bend) / st_length(bend);
    res.isolated = false;
    if st_numpoints(bend) >= 3 then
      polygon = st_makepolygon(st_addpoint(bend, st_startpoint(bend)));
      -- Compactness Index (cmp) is defined as "the ratio of the area of the
      -- polygon over the circle whose circumference length is the same as the
      -- length of the circumference of the polygon". I assume they meant the
      -- area of the circle. So here goes:
      -- 1. get polygon area P.
      -- 2. get polygon perimeter = u. Pretend it's our circle's circumference.
      -- 3. get A (area) of the circle from u: A = u^2/(4pi)
      -- 4. divide P by A: cmp = P/A = P/(u^2/(4pi)) = 4pi*P/u^2
      res.area = st_area(polygon);
      res.cmp = fourpi*res.area/(st_perimeter(polygon)^2);
      if res.cmp > 0 then
        res.adjsize = (res.area*(0.75/res.cmp));
      end if;
    end if;

    if dbgname is not null then
      insert into wm_debug (stage, name, nbend, way, props) values(
        'ebendattrs',
        dbgname,
        i,
        bend,
        jsonb_build_object(
          'area', res.area,
          'cmp', res.cmp,
          'adjsize', res.adjsize,
          'baselinelength', res.baselinelength,
          'curvature', res.curvature
        )
      );
    end if;
    return next res;
  end loop;
end;
$$ language plpgsql;

create function isolated_bends(
  INOUT bendattrs t_bend_attrs[],
  dbgname text default null
) as $$
declare
  -- if neighbor's curvatures are within, it's isolated
  isolation_threshold constant real default 0.25;
  this real;
  skip_next bool;
  res t_bend_attrs;
  i int4;
begin
  for i in 2..array_length(bendattrs, 1)-1 loop
    res = bendattrs[i];
    if skip_next then
      skip_next = false;
    else
      this = bendattrs[i].curvature * isolation_threshold;
      if bendattrs[i-1].curvature < this and bendattrs[i+1].curvature < this then
        res.isolated = true;
        bendattrs[i] = res;
        skip_next = true;
      end if;
    end if;

    if dbgname is not null then
      insert into wm_debug (stage, name, nbend, way, props) values(
        'fisolated_bends',
        dbgname,
        i,
        res.bend,
        jsonb_build_object(
          'isolated', res.isolated
        )
      );
    end if;

  end loop;
end
$$ language plpgsql;

-- ST_SimplifyWM simplifies a given geometry using Wang & Müller's
-- "Line Generalization Based on Analysis of Shape Characteristics" algorithm,
-- 1998.
drop function if exists ST_SimplifyWM;
create function ST_SimplifyWM(
  geom geometry,
  dbgname text default null
) returns geometry as $$
declare
  stagenum integer;
  i integer;
  line geometry;
  lines geometry[];
  bends geometry[];
  bend_attrs t_bend_attrs[];
  mutated boolean;
  l_type text;
begin
  l_type = st_geometrytype(geom);
  if l_type = 'ST_LineString' then
    lines = array[geom];
  elseif l_type = 'ST_MultiLineString' then
    lines = array((select a.geom from st_dump(geom) a order by path[1] asc));
  else
    raise 'Unknown geometry type %', l_type;
  end if;

  for i in 1..array_length(lines, 1) loop
    mutated = true;
    stagenum = 1;
    while mutated loop
      if dbgname is not null then
        insert into wm_debug (stage, name, gen, nbend, way) values(
          'afigures',
          dbgname,
          stagenum,
          i,
          lines[i]
        );
      end if;


      bends = detect_bends(lines[i], dbgname, stagenum);
      bends = fix_gentle_inflections(bends, dbgname, stagenum);

      select * from self_crossing(bends) into bends, mutated;

      if dbgname is not null then
        insert into wm_debug(stage, name, gen, nbend, way) values(
          'dcrossings',
          dbgname,
          stagenum,
          generate_subscripts(bends, 1),
          unnest(bends)
        );
      end if;

      if mutated then
        lines[i] = st_linemerge(st_union(bends));
        stagenum = stagenum + 1;
        continue;
      end if;

      -- self-crossing mutations are done, calculate bend properties
      bend_attrs = array((select bend_attrs(bends, dbgname)));

      perform isolated_bends(bend_attrs, dbgname);
    end loop;

  end loop;

  if l_type = 'ST_LineString' then
    return st_linemerge(st_union(lines));
  elseif l_type = 'ST_MultiLineString' then
    return st_union(lines);
  end if;
end
$$ language plpgsql;
