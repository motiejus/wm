\set ON_ERROR_STOP on
SET plpgsql.extra_errors TO 'all';

-- wm_detect_bends detects bends using the inflection angles. No corrections.
drop function if exists wm_detect_bends;
create function wm_detect_bends(
  line geometry,
  dbgname text default null,
  dbggen integer default null,
  OUT bends geometry[]
) as $$
declare
  p geometry;
  p1 geometry;
  p2 geometry;
  p3 geometry;
  bend geometry;
  prev_sign int4;
  cur_sign int4;
  l_type text;
  dbgpolygon geometry;
begin
  l_type = st_geometrytype(line);
  if l_type != 'ST_LineString' then
    raise notice 'Got non-LineString: %', st_summary(line);
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

    cur_sign = sign(pi() - st_angle(p1, p2, p2, p3));

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
        'bbends', dbgname, dbggen, i, bends[i]);

      dbgpolygon = null;
      if st_npoints(bends[i]) >= 3 then
          dbgpolygon = st_makepolygon(
            st_addpoint(bends[i],
              st_startpoint(bends[i]))
          );
      end if;
      insert into wm_debug(stage, name, gen, nbend, way) values(
        'bbends-polygon', dbgname, dbggen, i, dbgpolygon);
    end loop;
  end if;
end
$$ language plpgsql;

-- wm_fix_gentle_inflections moves bend endpoints following "Gentle Inflection
-- at End of a Bend" section.
--
-- The text does not specify how many vertices can be "adjusted"; it can
-- equally be one or many. This function is adjusting many, as long as the
-- cumulative inflection angle small (see variable below).
--
-- The implementation could be significantly optimized to avoid `st_reverse`
-- and array reversals, trading for complexity in wm_fix_gentle_inflections1.
drop function if exists wm_fix_gentle_inflections;
create function wm_fix_gentle_inflections(
  INOUT bends geometry[],
  dbgname text default null,
  dbggen integer default null
) as $$
declare
  len int4;
  bends1 geometry[];
  dbgpolygon geometry;
begin
  len = array_length(bends, 1);

  bends = wm_fix_gentle_inflections1(bends);
  for i in 1..len loop
    bends1[i] = st_reverse(bends[len-i+1]);
  end loop;
  bends1 = wm_fix_gentle_inflections1(bends1);

  for i in 1..len loop
    bends[i] = st_reverse(bends1[len-i+1]);
  end loop;

  if dbgname is not null then
    for i in 1..array_length(bends, 1) loop
      insert into wm_debug(stage, name, gen, nbend, way) values(
        'cinflections', dbgname, dbggen, i, bends[i]);

      dbgpolygon = null;
      if st_npoints(bends[i]) >= 3 then
        dbgpolygon = st_makepolygon(
          st_addpoint(bends[i],
            st_startpoint(bends[i]))
        );
      end if;

      insert into wm_debug(stage, name, gen, nbend, way) values(
        'cinflections-polygon', dbgname, dbggen, i, dbgpolygon);
    end loop;
  end if;
end
$$ language plpgsql;

-- wm_fix_gentle_inflections1 fixes gentle inflections of an array of lines in
-- one direction. An implementation detail of wm_fix_gentle_inflections.
drop function if exists wm_fix_gentle_inflections1;
create function wm_fix_gentle_inflections1(INOUT bends geometry[]) as $$
declare
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
      exit when abs(st_angle(phead[1], phead[2], phead[3]) - pi()) > small_angle;

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

-- wm_if_selfcross returns whether baseline of bendi crosses bendj.
-- If it doesn't, returns a null geometry.
-- Otherwise, it will return the baseline split into a few parts where it
-- crosses bendj.
drop function if exists wm_if_selfcross;
create function wm_if_selfcross(
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


-- wm_self_crossing eliminates self-crossing from the bends, following the
-- article's section "Self-line Crossing When Cutting a Bend".
drop function if exists wm_self_crossing;
create function wm_self_crossing(
  INOUT bends geometry[],
  dbgname text default null,
  dbggen integer default null,
  OUT mutated boolean
) as $$
declare
  i int4;
  j int4;
  multi geometry;
begin
  mutated = false;
  <<bendloop>>
  for i in 1..array_length(bends, 1) loop
    continue when abs(wm_inflection_angle(bends[i])) <= pi();
    -- sum of inflection angles for this bend is >180, so it may be
    -- self-crossing. Now try to find another bend in this line that
    -- crosses an imaginary line of end-vertices

    -- Go through each bend in the given line, and see if has a potential to
    -- cross bends[i]. The line-cut process is different when i<j and i>j;
    -- therefore there are two loops, one for each case.
    for j in 1..i-1 loop
      multi = wm_if_selfcross(bends[i], bends[j]);
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
      multi = wm_if_selfcross(bends[i], bends[j]);
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

  if dbgname is not null then
    insert into wm_debug(stage, name, gen, nbend, way) values(
      'dcrossings', dbgname, dbggen, generate_subscripts(bends, 1),
      unnest(bends)
    );
  end if;
end
$$ language plpgsql;

drop function if exists wm_inflection_angle;
create function wm_inflection_angle (IN bend geometry, OUT angle real) as $$
declare
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
    angle = angle + abs(pi() - st_angle(p1, p2, p3));
  end loop;
end
$$ language plpgsql;

drop function if exists wm_bend_attrs;
drop function if exists wm_isolated_bends;
drop function if exists wm_elimination;
drop function if exists wm_exaggeration;
drop type if exists wm_t_bend_attrs;
create type wm_t_bend_attrs as (
  bend geometry,
  area real,
  adjsize real,
  baselinelength real,
  curvature real,
  isolated boolean
);
create function wm_bend_attrs(
  bends geometry[],
  dbgname text default null,
  dbggen integer default null
) returns setof wm_t_bend_attrs as $$
declare
  cmp float;
  i int4;
  polygon geometry;
  bend geometry;
  res wm_t_bend_attrs;
begin
  for i in 1..array_length(bends, 1) loop
    bend = bends[i];
    res = null;
    res.bend = bend;
    res.adjsize = 0;
    res.baselinelength = st_distance(st_startpoint(bend), st_endpoint(bend));
    res.curvature = wm_inflection_angle(bend) / st_length(bend);
    res.isolated = false;
    if st_numpoints(bend) >= 3 then
      res.adjsize = wm_adjsize(bend);
    end if;

    if dbgname is not null then
      insert into wm_debug (stage, name, gen, nbend, way, props) values(
        'ebendattrs', dbgname, dbggen, i, bend,
        jsonb_build_object(
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

-- splits a line by a point in a more robust way than st_split
-- (see https://trac.osgeo.org/postgis/ticket/2192)
drop function if exists wm_st_split;
create function wm_st_split(
  input geometry,
  blade geometry
) returns geometry as $$
declare
  type1 text;
  type2 text;
begin
  type1 = st_geometrytype(input);
  type2 = st_geometrytype(blade);
  if not (type1 = 'ST_LineString' and
          type2 = 'ST_Point') then
    raise 'Arguments must be LineString and Point, got: % and %', type1, type2;
  end if;
  return st_split(st_snap(input, blade, 0.00000001), blade);
end $$ language plpgsql;

-- wm_exaggerate_bend exaggerates a given bend. Must be a simple linestring.
drop function if exists wm_exaggerate_bend;
create function wm_exaggerate_bend(
  INOUT bend geometry,
  size float,
  desired_size float
) as $$
declare
  scale constant float default 2; -- per-step scaling factor
  midpoint geometry; -- midpoint of the baseline
  splitbend geometry; -- bend split across its half
  bendm geometry; -- bend with coefficients to prolong the lines
  points geometry[];
begin
  if size = 0 then
    raise 'unable to exaggerate a zero-area bend';
  end if;
  midpoint = st_lineinterpolatepoint(st_makeline(
      st_pointn(bend, 1),
      st_pointn(bend, -1)
    ), .5);

  insert into wm_manual (name, way) values ('midpoint', midpoint);

  while size < desired_size loop
    splitbend = wm_st_split(bend, st_lineinterpolatepoint(bend, .5));

    -- Convert bend to LINESTRINGM, where M is the fraction by how
    -- much the point will be prolonged:
    -- 1. draw a line between midpoint and the point on the bend.
    -- 2. multiply the line length by M. Midpoint stays intact.
    -- 3. the new set of lines form a new bend.

    -- Uses linear interpolation; can be updated to gaussian or similar;
    -- then interpolate manually instead of relying on st_addmeasure.
    bendm = st_collect(
      st_addmeasure(st_geometryn(splitbend, 1), 1, scale),
      st_addmeasure(st_geometryn(splitbend, 2), scale, 1)
    );

    points = array((
        select st_scale(
          st_makepoint(st_x(geom), st_y(geom)),
          st_makepoint(st_m(geom), st_m(geom)),
          midpoint
        )
        from st_dumppoints(bendm)
        order by path[1], path[2]
      ));

    bend = st_setsrid(st_makeline(points), st_srid(bend));
    size = wm_adjsize(bend);
  end loop;
end
$$ language plpgsql;

-- wm_adjsize calculates adjusted size for a polygon. Can return 0.
drop function if exists wm_adjsize;
create function wm_adjsize(bend geometry, OUT adjsize float) as $$
declare
  polygon geometry;
  area float;
  cmp float;
begin
  adjsize = 0;
  polygon = st_makepolygon(st_addpoint(bend, st_startpoint(bend)));
  -- Compactness Index (cmp) is defined as "the ratio of the area of the
  -- polygon over the circle whose circumference length is the same as the
  -- length of the circumference of the polygon". I assume they meant the
  -- area of the circle. So here goes:
  -- 1. get polygon area P.
  -- 2. get polygon perimeter = u. Pretend it's our circle's circumference.
  -- 3. get A (area) of the circle from u: A = u^2/(4pi)
  -- 4. divide P by A: cmp = P/A = P/(u^2/(4pi)) = 4pi*P/u^2
  area = st_area(polygon);
  cmp = 4*pi()*area/(st_perimeter(polygon)^2);
  if cmp > 0 then
    adjsize = (area*(0.75/cmp));
  end if;
end
$$ language plpgsql;

-- wm_exaggeration is the Exaggeration Operator described in the WM paper.
create function wm_exaggeration(
  INOUT bendattrs wm_t_bend_attrs[],
  dhalfcircle float,
  dbgname text default null,
  dbggen integer default null,
  OUT mutated boolean
) as $$
declare
  desired_size constant float default pi()*(dhalfcircle^2)/8;
  tmpbendattr wm_t_bend_attrs;
  i integer;
  last_id integer;
begin
  mutated = false;
  for i in 1..array_length(bendattrs, 1) loop

    if bendattrs[i].isolated and bendattrs[i].adjsize < desired_size then
      mutated = true;
      tmpbendattr.bend = wm_exaggerate_bend(
        bendattrs[i].bend,
        bendattrs[i].adjsize,
        desired_size
      );
      bendattrs[i] = tmpbendattr;

      -- remove last vertex of the previous bend and
      -- first vertex of the next bend, because bends always
      -- share a line segment together
      -- this is duplicated in a few places, because PostGIS
      -- does not allow (?) mutating an array when passed to a
      -- function.
      tmpbendattr.bend = st_removepoint(
        bendattrs[i-1].bend,
        st_npoints(bendattrs[i-1].bend)-1
      );
      bendattrs[i-1] = tmpbendattr;
      tmpbendattr.bend = st_removepoint(bendattrs[i+1].bend, 0);
      bendattrs[i+1] = tmpbendattr;

      if dbgname is not null then
        insert into wm_debug (stage, name, gen, nbend, way) values(
          'gexaggeration', dbgname, dbggen, i, bendattrs[i].bend
        );
      end if;
    end if;

  end loop;

end
$$ language plpgsql;

create function wm_elimination(
  INOUT bendattrs wm_t_bend_attrs[],
  dhalfcircle float,
  dbgname text default null,
  dbggen integer default null,
  OUT mutated boolean
) as $$
declare
  desired_size constant float default pi()*(dhalfcircle^2)/8;
  leftsize float;
  rightsize float;
  i int4;
  j int4;
  tmpbendattr wm_t_bend_attrs;
  dbgbends geometry[];
begin
  mutated = false;

  i = 1;
  while i < array_length(bendattrs, 1)-1 loop
    i = i + 1;
    continue when bendattrs[i].adjsize = 0;
    continue when bendattrs[i].adjsize > desired_size;

    if i = 2 then
      leftsize = bendattrs[i].adjsize + 1;
    else
      leftsize = bendattrs[i-1].adjsize;
    end if;

    if i = array_length(bendattrs, 1)-1 then
      rightsize = bendattrs[i].adjsize + 1;
    else
      rightsize = bendattrs[i+1].adjsize;
    end if;

    continue when bendattrs[i].adjsize >= leftsize;
    continue when bendattrs[i].adjsize >= rightsize;

    -- Local minimum. Elminate bend!
    mutated = true;
    tmpbendattr.bend = st_makeline(
      st_pointn(bendattrs[i].bend, 1),
      st_pointn(bendattrs[i].bend, -1)
    );
    bendattrs[i] = tmpbendattr;
    -- remove last vertex of the previous bend and
    -- first vertex of the next bend, because bends always
    -- share a line segment together
    tmpbendattr.bend = st_removepoint(
      bendattrs[i-1].bend,
      st_npoints(bendattrs[i-1].bend)-1
    );
    bendattrs[i-1] = tmpbendattr;
    tmpbendattr.bend = st_removepoint(bendattrs[i+1].bend, 0);
    bendattrs[i+1] = tmpbendattr;
    -- the next bend's adjsize is now messed up; it should not be taken
    -- into consideration for other local minimas. Skip over 2.
    i = i + 2;
  end loop;

  if dbgname is not null then
    for j in 1..array_length(bendattrs, 1) loop
      dbgbends[j] = bendattrs[j].bend;
    end loop;

    insert into wm_debug(stage, name, gen, nbend, way) values(
      'helimination',
      dbgname,
      dbggen,
      generate_subscripts(dbgbends, 1),
      unnest(dbgbends)
    );
  end if;
end
$$ language plpgsql;

create function wm_isolated_bends(
  INOUT bendattrs wm_t_bend_attrs[],
  dbgname text default null,
  dbggen integer default null
) as $$
declare
  -- if neighbor's curvatures are within this fraction of the current bend
  isolation_threshold constant real default 0.5;
  this real;
  skip_next bool;
  res wm_t_bend_attrs;
  i int4;
  last_id integer;
begin
  for i in 1..array_length(bendattrs, 1) loop
    if dbgname is not null then
      insert into wm_debug (stage, name, gen, nbend, way, props) values(
        'fisolated_bends', dbgname, dbggen, i, bendattrs[i].bend,
        jsonb_build_object('isolated', false)
      ) returning id into last_id;
    end if;
    -- first and last bends cannot be isolated
    if i = 1 or i = array_length(bendattrs, 1) then
      continue;
    end if;

    res = bendattrs[i];
    if skip_next then
      skip_next = false;
    else
      this = bendattrs[i].curvature * isolation_threshold;
      if bendattrs[i-1].curvature < this and
         bendattrs[i+1].curvature < this then
        res.isolated = true;
        bendattrs[i] = res;
        skip_next = true;

        if dbgname is not null then
          update wm_debug
          set props=props || jsonb_build_object('isolated', true)
          where id=last_id;
        end if;
      end if;
    end if;

  end loop;
end
$$ language plpgsql;

drop function if exists ST_SimplifyWM_Estimate;
create function ST_SimplifyWM_Estimate(
  geom geometry,
  OUT npoints bigint,
  OUT secs bigint
) as $$
declare
  lines geometry[];
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

  npoints = 0;
  for i in 1..array_length(lines, 1) loop
    npoints = npoints + st_numpoints(lines[i]);
  end loop;
  secs = npoints / 150;
end
$$ language plpgsql;

-- ST_SimplifyWM simplifies a given geometry using Wang & Müller's
-- "Line Generalization Based on Analysis of Shape Characteristics" algorithm,
-- 1998.
-- Input parameters:
-- - geom: ST_LineString or ST_MultiLineString: the geometry to be simplified
-- - dhalfcircle: the diameter of a half-circle, whose area is an approximate
--   threshold for small bend elimination. If bend's area is larger than that,
--   the bend will be left alone.
drop function if exists ST_SimplifyWM;
create function ST_SimplifyWM(
  geom geometry,
  dhalfcircle float,
  dbgname text default null
) returns geometry as $$
declare
  gen integer;
  i integer;
  j integer;
  line geometry;
  lines geometry[];
  bends geometry[];
  bendattrs wm_t_bend_attrs[];
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
    gen = 1;
    while mutated loop
      if dbgname is not null then
        insert into wm_debug (stage, name, gen, nbend, way) values(
          'afigures', dbgname, gen, i, lines[i]);
      end if;

      bends = wm_detect_bends(lines[i], dbgname, gen);
      bends = wm_fix_gentle_inflections(bends, dbgname, gen);

      select * from wm_self_crossing(bends, dbgname, gen) into bends, mutated;

      if mutated then
        lines[i] = st_linemerge(st_union(bends));
        gen = gen + 1;
        continue;
      end if;

      bendattrs = array((select wm_bend_attrs(bends, dbgname, gen)));
      bendattrs = wm_isolated_bends(bendattrs, dbgname, gen);

      select * from wm_exaggeration(
        bendattrs, dhalfcircle, dbgname, gen) into bendattrs, mutated;

      -- TODO: wm_combination

      if not mutated then
        select * from wm_elimination(
          bendattrs, dhalfcircle, dbgname, gen) into bendattrs, mutated;
      end if;

      if mutated then
        for j in 1..array_length(bendattrs, 1) loop
          bends[j] = bendattrs[j].bend;
        end loop;
        lines[i] = st_linemerge(st_union(bends));
        gen = gen + 1;
        continue;
      end if;

    end loop;

  end loop;

  if l_type = 'ST_LineString' then
    return st_linemerge(st_union(lines));
  elseif l_type = 'ST_MultiLineString' then
    return st_union(lines);
  end if;
end
$$ language plpgsql;
