\i wm.sql

-- https://stackoverflow.com/questions/19982373/which-tools-libraries-do-you-use-to-unit-test-your-pl-pgsql
CREATE OR REPLACE FUNCTION assert_equals(expected anyelement, actual anyelement) RETURNS void AS $$
begin
  if expected = actual or (expected is null and actual is null) then
    --do nothing
  else
    raise exception 'Assertion Error. Expected <%> but was <%>', expected, actual;
  end if;
end $$ LANGUAGE plpgsql;

drop table if exists figures;
create table figures (name text, way geometry);
-- to "normalize" a new line when it's in `f`:
--   select st_astext(st_snaptogrid(st_transscale(geometry, 80, 130, .3, .3), 1)) from f;
insert into figures (name, way) values ('fig3',ST_GeomFromText('LINESTRING(0 0,12 0,13 4,20 2,20 0,32 0,33 10,38 16,43 15,44 10,44 0,60 0)'));
insert into figures (name, way) values ('fig3-1',ST_GeomFromText('LINESTRING(0 0,12 0,13 4,20 2,20 0,32 0,33 10,38 16,43 15,44 10,44 0)'));
insert into figures (name, way) values ('fig5',ST_GeomFromText('LINESTRING(0 39,19 52,27 77,26 104,41 115,49 115,65 103,65 75,53 45,63 15,91 0)'));
insert into figures (name, way) values ('fig6',ST_GeomFromText('LINESTRING(84 47,91 59,114 64,122 80,116 92,110 93,106 106,117 118,136 107,135 76,120 45,125 39,141 39,147 32)'));
insert into figures (name, way) values ('fig6-rev',ST_Reverse(ST_Translate((select way from figures where name='fig6'), 60, 0)));
insert into figures (name, way) values ('fig6-combi',
  ST_LineMerge(ST_Union(
      ST_Translate((select way from figures where name='fig6'), 0, 90),
      ST_Translate((select way from figures where name='fig6'), 80, 90)
  ))
);
insert into figures (name, way) values ('inflection-1',ST_GeomFromText('LINESTRING(110 24,114 20,133 20,145 15,145 0,136 5,123 7,114 7,111 2)'));
insert into figures (name, way) values ('multi',ST_GeomFromText('MULTILINESTRING((-10 -6,-5 -5,0 5,10 6),(-5 -5,-1 -1,0 0,1 -1,5 -5))'));

drop table if exists debug;
create table debug (i bigint, way geometry);

-- DETECT BENDS
drop table if exists bends, demo_bends1;
create table bends (name text, ways geometry[]);
insert into bends select name, detect_bends(way) from figures;
create table demo_bends1 (name text, i bigint, way geometry);
insert into demo_bends1 select name, generate_subscripts(ways, 1), unnest(ways) from bends;

-- FIX BEND INFLECTIONS
drop table if exists inflections, demo_inflections2;
create table inflections (name text, ways geometry[]);
insert into inflections select name, fix_gentle_inflections(ways) from bends;
create table demo_inflections2 (name text, i bigint, way geometry);
insert into demo_inflections2 select name, generate_subscripts(ways, 1), unnest(ways) from inflections;

-- SELF-LINE CROSSING
drop table if exists selfcrossing, demo_selfcrossing3;
create table selfcrossing (name text, ways geometry[], mutated boolean);
insert into selfcrossing select name, (self_crossing(ways)).* from inflections;
create table demo_selfcrossing3 (name text, i bigint, way geometry);
insert into demo_selfcrossing3 select name, generate_subscripts(ways, 1), unnest(ways) from selfcrossing;

-- COMBINED
drop table if exists demo_wm;
create table demo_wm (name text, i bigint, way geometry);
insert into demo_wm (name, way) select name, ST_SimplifyWM_DEBUG(way) from figures where name='multi';

do $$
declare
  vbends geometry[];
begin
  select detect_bends((select way from figures where name='fig3')) into vbends;
  perform assert_equals(5, array_length(vbends, 1));
  perform assert_equals('LINESTRING(0 0,12 0,13 4)', st_astext(vbends[1]));
  perform assert_equals('LINESTRING(12 0,13 4,20 2,20 0)', st_astext(vbends[2]));
  perform assert_equals('LINESTRING(20 2,20 0,32 0,33 10)', st_astext(vbends[3]));
  perform assert_equals('LINESTRING(32 0,33 10,38 16,43 15,44 10,44 0)', st_astext(vbends[4]));
  perform assert_equals(4, array_length(detect_bends((select way from figures where name='fig3-1')), 1));
  select detect_bends((select way from figures where name='fig5')) into vbends;
  perform assert_equals(3, array_length(vbends, 1));
end $$ language plpgsql;

do $$
declare
  vbends geometry[];
  vinflections geometry[];
begin
  -- fig5
  select fix_gentle_inflections((select ways from bends where name='fig5')) into vinflections;
  perform assert_equals('LINESTRING(0 39,19 52,27 77)', st_astext(vinflections[1]));
  perform assert_equals('LINESTRING(19 52,27 77,26 104,41 115,49 115,65 103,65 75,53 45)', st_astext(vinflections[2]));
  perform assert_equals('LINESTRING(65 75,53 45,63 15,91 0)', st_astext(vinflections[3]));

  -- inflections-1, the example in fix_gentle_inflections docstring
  select ways from bends where name='inflection-1' into vbends;
  select fix_gentle_inflections(vbends) into vinflections;
  perform assert_equals(vbends[1], vinflections[1]); -- unchanged
  perform assert_equals('LINESTRING(114 20,133 20,145 15,145 0,136 5,123 7,114 7)', st_astext(vinflections[2]));
  perform assert_equals('LINESTRING(123 7,114 7,111 2)', st_astext(vinflections[3]));
end $$ language plpgsql;

do $$
declare
  vcrossings geometry[];
  mutated boolean;
begin
  select (self_crossing((select ways from inflections where name='fig6'))).* into vcrossings, mutated;
  perform assert_equals(true, mutated);
  perform assert_equals(
    'LINESTRING(84 47,91 59,114 64,120 45,125 39,141 39,147 32)',
    (select st_astext(
        st_linemerge(st_union(way))
    ) from (select unnest(vcrossings) way) a)
  );

  select (self_crossing((select ways from inflections where name='fig6-rev'))).* into vcrossings, mutated;
  perform assert_equals(true, mutated);
  perform assert_equals(
    'LINESTRING(84 47,91 59,114 64,120 45,125 39,141 39,147 32)',
    (select st_astext(
        st_translate(st_reverse(st_linemerge(st_union(way))), -60, 0)
    ) from (select unnest(vcrossings) way) a)
  );

  select (self_crossing((select ways from inflections where name='fig6-combi'))).* into vcrossings, mutated;
  perform assert_equals(true, mutated);
  perform assert_equals(
    'LINESTRING(84 137,91 149,114 154,120 135,125 129,141 129,147 122,164 137,171 149,194 154,200 135,205 129,221 129,227 122)',
    (select st_astext(
        st_linemerge(st_union(way))
    ) from (select unnest(vcrossings) way) a)
  );

end $$ language plpgsql;
