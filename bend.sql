\set ON_ERROR_STOP on
SET plpgsql.extra_errors TO 'all';

create or replace function detect_bends(line geometry) returns table(bend geometry) as $$
/* for each bend, should return:
   - size (area)
   - shape (cmp, compactness index)
*/
declare
  pi real;
  p geometry;
  p1 geometry;
  p2 geometry;
  p3 geometry;
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
        return next;
      end if;
      bend = st_makeline(p3, p2);
    end if;
    prev_sign = cur_sign;
  end loop;
end
$$ language plpgsql;

drop table if exists bends;

--create table bends as (select * from detect_bends((select way from figures where name='fig3')));
create table bends as (select * from detect_bends((select way from figures where name='Žeimena')));
