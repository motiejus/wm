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
insert into figures (name, way) values ('fig3', ST_GeomFromText('LINESTRING(0 0, 12 0, 13 4, 20 2, 20 0, 32 0, 33 10, 38 16, 43 15, 44 10, 44 0, 60 0)'));
insert into figures (name, way) values ('fig3-1', ST_GeomFromText('LINESTRING(0 0, 12 0, 13 4, 20 2, 20 0, 32 0, 33 10, 38 16, 43 15, 44 10, 44 0)'));

do $$
begin
  perform assert_equals(3::bigint, (select count(1) from detect_bends((select way from figures where name='fig3'))));
  perform assert_equals(3::bigint, (select count(1) from detect_bends((select way from figures where name='fig3-1'))));
end $$ language plpgsql;
