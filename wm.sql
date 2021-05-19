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
            st_addpoint(bends[i], st_startpoint(bends[i]))
          );
      end if;
      insert into wm_debug(stage, name, gen, nbend, way) values(
        'bbends-polygon', dbgname, dbggen, i, dbgpolygon);
    end loop;
  end if;
end $$ language plpgsql;

-- wm_fix_gentle_inflections moves bend endpoints following "Gentle Inflection
-- at End of a Bend" section.
--
-- The text does not specify how many vertices can be "adjusted"; it can
-- equally be one or many. This function is adjusting many, as long as the
-- cumulative inflection angle is small (see variable below).
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
end $$ language plpgsql;

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
end $$ language plpgsql;

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
end $$ language plpgsql;

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
end $$ language plpgsql;

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
end $$ language plpgsql;

drop function if exists wm_bend_attrs;
drop function if exists wm_elimination;
drop function if exists wm_exaggeration;
drop type if exists wm_t_attrs;
create type wm_t_attrs as (
  adjsize real,
  baselinelength real,
  curvature real,
  isolated boolean
);
create function wm_bend_attrs(
  bends geometry[],
  dbgname text default null,
  dbggen integer default null
) returns wm_t_attrs[] as $$
declare
  isolation_threshold constant real default 0.5;
  attrs wm_t_attrs[];
  attr wm_t_attrs;
  bend geometry;
  i int4;
  needs_curvature real;
  skip_next boolean;
  dbglastid integer;
begin
  for i in 1..array_length(bends, 1) loop
    bend = bends[i];
    attr.adjsize = 0;
    attr.baselinelength = st_distance(st_startpoint(bend), st_endpoint(bend));
    attr.curvature = wm_inflection_angle(bend) / st_length(bend);
    attr.isolated = false;
    if st_numpoints(bend) >= 3 then
      attr.adjsize = wm_adjsize(bend);
    end if;
    attrs[i] = attr;
  end loop;

  for i in 1..array_length(attrs, 1) loop
    if dbgname is not null then
      insert into wm_debug (stage, name, gen, nbend, way, props) values(
        'ebendattrs', dbgname, dbggen, i, bends[i],
        jsonb_build_object(
          'adjsize', attrs[i].adjsize,
          'baselinelength', attrs[i].baselinelength,
          'curvature', attrs[i].curvature,
          'isolated', false
        )
      ) returning id into dbglastid;
    end if;

    -- first and last bends can never be isolated by definition
    if skip_next or i = 1 or i = array_length(attrs, 1) then
      -- invariant: two bends that touch cannot be isolated.
      if st_npoints(bends[i]) > 3 then
        skip_next = false;
      end if;
      continue;
    end if;

    needs_curvature = attrs[i].curvature * isolation_threshold;
    if attrs[i-1].curvature < needs_curvature and
       attrs[i+1].curvature < needs_curvature then
      attr = attrs[i];
      attr.isolated = true;
      attrs[i] = attr;
      skip_next = true;

      if dbgname is not null then
        update wm_debug
        set props=props || jsonb_build_object('isolated', true)
        where id=dbglastid;
      end if;
    end if;
  end loop;

  return attrs;
end $$ language plpgsql;

-- sm_st_split a line by a point in a more robust way than st_split.
-- See https://trac.osgeo.org/postgis/ticket/2192
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


drop function if exists wm_exaggerate_bend2;
create function wm_exaggerate_bend2(
  INOUT bend geometry,
  size float,
  desired_size float
) as $$
declare
  scale constant float default 1.2; -- exaggeration enthusiasm
  midpoint geometry; -- midpoint of the baseline
  points geometry[];
  startazimuth float;
  azimuth float;
  diffazimuth float;
  point geometry;
  sss float;
  protect int = 10;
begin
  if size = 0 then
    raise 'invalid input: zero-area bend';
  end if;
  midpoint = st_lineinterpolatepoint(st_makeline(
      st_pointn(bend, 1),
      st_pointn(bend, -1)
    ), .5);
  startazimuth = st_azimuth(midpoint, st_pointn(bend, 1));

  while (size < desired_size) and (protect > 0) loop
    protect = protect - 1;
    for i in 2..st_npoints(bend)-1 loop
      point = st_pointn(bend, i);
      azimuth = st_azimuth(midpoint, point);
      diffazimuth = degrees(azimuth - startazimuth);
      if diffazimuth > 180 then
        diffazimuth = diffazimuth - 360;
      elseif diffazimuth < -180 then
        diffazimuth = diffazimuth + 360;
      end if;
      diffazimuth = abs(diffazimuth);
      if diffazimuth > 90 then
        diffazimuth = 180 - diffazimuth;
      end if;
      sss = ((scale-1) * (diffazimuth / 90)^0.5);
      point = st_transform(
        st_project(
          st_transform(point, 4326)::geography,
          st_distance(midpoint, point) * sss, azimuth)::geometry,
        st_srid(midpoint)
      );
      bend = st_setpoint(bend, i-1, point);
    end loop;
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
end $$ language plpgsql;

-- wm_exaggeration is the Exaggeration Operator described in the WM paper.
create function wm_exaggeration(
  INOUT bends geometry[],
  attrs wm_t_attrs[],
  dhalfcircle float,
  intersect_patience integer,
  dbgname text default null,
  dbggen integer default null,
  OUT mutated boolean
) as $$
declare
  desired_size constant float default pi()*(dhalfcircle^2)/8;
  bend geometry;
  tmpint geometry;
  i integer;
  n integer;
  last_id integer;
begin
  mutated = false;
  <<bendloop>>
  for i in 1..array_length(attrs, 1) loop
    if attrs[i].isolated and attrs[i].adjsize < desired_size then
      bend = wm_exaggerate_bend2(bends[i], attrs[i].adjsize, desired_size);
      -- Does bend intersect with the previous or next
      -- intersect_patience bends? If they do, abort exaggeration for this one.

      -- Do close-by bends intersect with this one? Special
      -- handling first, because 2 vertices need to be removed before checking.
      n = st_npoints(bends[i-1]);
      if n > 3 then
        continue when st_intersects(bend,
          st_removepoint(st_removepoint(bends[i-1], n-1), n-2));
      end if;
      if n > 2 then
        tmpint = st_intersection(bend, st_removepoint(bends[i-1], n-1));
        continue when st_npoints(tmpint) > 1;
      end if;

      n = st_npoints(bends[i+1]);
      if n > 3 then
        continue when st_intersects(bend,
          st_removepoint(st_removepoint(bends[i+1], 0), 0));
      end if;
      if n > 2 then
        tmpint = st_intersection(bend, st_removepoint(bends[i+1], 0));
        continue when st_npoints(tmpint) > 1;
      end if;

      for n in -intersect_patience+1..intersect_patience-1 loop
        continue when n in (-1, 0, 1);
        continue when i+n < 1;
        continue when i+n > array_length(attrs, 1);

        -- More special handling: if the neigbhoring bend has 3 vertices, the
        -- neighbor's neighbor may just touch the tmpbendattr.bend; in this
        -- case, the nearest vertex should be removed before comparing.
        tmpint = bends[i+n];
        if st_npoints(tmpint) > 2 then
          if n = -2 and st_npoints(bends[i+n+1]) = 3 then
            tmpint = st_removepoint(tmpint, st_npoints(tmpint)-1);
          elsif n = 2 and st_npoints(bends[i+n-1]) = 3 then
            tmpint = st_removepoint(tmpint, 0);
          end if;
        end if;

        continue bendloop when st_intersects(bend, tmpint);
      end loop;

      -- No intersections within intersect_patience, mutate bend!
      mutated = true;
      bends[i] = bend;

      -- remove last vertex of the previous bend and first vertex of the next
      -- bend, because bends always share a line segment together this is
      -- duplicated in a few places, because PostGIS does not allow (?)
      -- mutating an array when passed to a function.
      bends[i-1] = st_addpoint(
        st_removepoint(bends[i-1], st_npoints(bends[i-1])-1),
        st_pointn(bends[i], 1),
        -1
      );

      bends[i+1] = st_addpoint(
        st_removepoint(bends[i+1], 0),
        st_pointn(bends[i], st_npoints(bends[i])-1),
        0
      );
      if dbgname is not null then
        insert into wm_debug (stage, name, gen, nbend, way) values(
          'gexaggeration', dbgname, dbggen, i, bends[i]);
      end if;
    end if;
  end loop;
end $$ language plpgsql;

create function wm_elimination(
  INOUT bends geometry[],
  attrs wm_t_attrs[],
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
begin
  mutated = false;

  i = 1;
  while i < array_length(attrs, 1)-1 loop
    i = i + 1;
    continue when attrs[i].adjsize = 0;
    continue when attrs[i].adjsize > desired_size;

    if i = 2 then
      leftsize = attrs[i].adjsize + 1;
    else
      leftsize = attrs[i-1].adjsize;
    end if;

    if i = array_length(attrs, 1)-1 then
      rightsize = attrs[i].adjsize + 1;
    else
      rightsize = attrs[i+1].adjsize;
    end if;

    continue when attrs[i].adjsize >= leftsize;
    continue when attrs[i].adjsize >= rightsize;

    -- Local minimum. Elminate bend!
    mutated = true;
    bends[i] = st_makeline(st_pointn(bends[i], 1), st_pointn(bends[i], -1));

    -- remove last vertex of the previous bend and
    -- first vertex of the next bend, because bends always
    -- share a line segment together
    bends[i-1] = st_addpoint(
      st_removepoint(bends[i-1], st_npoints(bends[i-1])-1),
      st_pointn(bends[i], 1),
      -1
    );

    bends[i+1] = st_addpoint(
      st_removepoint(bends[i+1], 0),
      st_pointn(bends[i], st_npoints(bends[i])-1),
      0
    );
    -- the next bend's adjsize is now messed up; it should not be taken
    -- into consideration for other local minimas. Skip over 2.
    i = i + 2;
  end loop;

  if dbgname is not null then
    insert into wm_debug(stage, name, gen, nbend, way) values(
      'helimination',
      dbgname,
      dbggen,
      generate_subscripts(bends, 1),
      unnest(bends)
    );
  end if;
end $$ language plpgsql;


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
  secs = npoints / 33;
end $$ language plpgsql;

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
  intersect_patience integer default 10,
  dbgname text default null
) returns geometry as $$
declare
  gen integer;
  i integer;
  j integer;
  line geometry;
  lines geometry[];
  bends geometry[];
  attrs wm_t_attrs[];
  mutated boolean;
  l_type text;
begin
  if intersect_patience is null then
    intersect_patience = 10;
  end if;
  l_type = st_geometrytype(geom);
  if l_type = 'ST_LineString' then
    lines = array[geom];
  elseif l_type = 'ST_MultiLineString' then
    lines = array((select a.geom from st_dump(geom) a order by path[1] asc));
  else
    raise 'Unknown geometry type %', l_type;
  end if;

  <<lineloop>>
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
      if not mutated then
        attrs = wm_bend_attrs(bends, dbgname, gen);

        select * from wm_exaggeration(bends, attrs,
          dhalfcircle, intersect_patience, dbgname, gen) into bends, mutated;
      end if;

      -- TODO: wm_combination

      if not mutated then
        select * from wm_elimination(bends, attrs,
          dhalfcircle, dbgname, gen) into bends, mutated;
      end if;

      if mutated then
        lines[i] = st_linemerge(st_union(bends));

        if st_geometrytype(lines[i]) != 'ST_LineString' then
          -- For manual debugging:
          --insert into wm_manual(name, way)
          --select 'non-linestring-' || a.path[1], a.geom
          --from st_dump(lines[i]) a
          --order by a.path[1];
          raise '[%] Got % (in %) instead of ST_LineString. '
          'Does the exaggerated bend intersect with the line? '
          'If so, try increasing intersect_patience.',
          gen, st_geometrytype(lines[i]), dbgname;
          --exit lineloop;
        end if;
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
end $$ language plpgsql;
