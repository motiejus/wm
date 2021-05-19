create schema if not exists test;
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
insert into figures (name, way) values ('fig3',ST_GeomFromText('LINESTRING(0 0,12 0,13 4,20 2,20 0,32 0,33 10,38 16,43 15,44 10,44 0,60 0)'));
insert into figures (name, way) values ('fig3-1',ST_GeomFromText('LINESTRING(0 0,12 0,13 4,20 2,20 0,32 0,33 10,38 16,43 15,44 10,44 0)'));
insert into figures (name, way) values ('fig5',ST_GeomFromText('LINESTRING(0 39,19 52,27 77,26 104,41 115,49 115,65 103,65 75,53 45,63 15,91 0,91 0)'));

drop table if exists bends;
create table bends (way geometry);
insert into bends select unnest(detect_bends((select way from figures where name='fig3')));
insert into bends select unnest(detect_bends((select way from figures where name='fig5')));

do $$
declare
  bends geometry[];
begin
  select detect_bends((select way from figures where name='fig3')) into bends;
  perform assert_equals(5, array_length(bends, 1));
  perform assert_equals('LINESTRING(0 0,12 0,13 4)', st_astext(bends[1]));
  perform assert_equals('LINESTRING(12 0,13 4,20 2,20 0)', st_astext(bends[2]));
  perform assert_equals('LINESTRING(20 2,20 0,32 0,33 10)', st_astext(bends[3]));
  perform assert_equals('LINESTRING(32 0,33 10,38 16,43 15,44 10,44 0)', st_astext(bends[4]));


  perform assert_equals(4, array_length(detect_bends((select way from figures where name='fig3-1')), 1));

  select detect_bends((select way from figures where name='fig5')) into bends;
  perform assert_equals(3, array_length(bends, 1));
end $$ language plpgsql;
