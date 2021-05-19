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
begin
  pi = radians(180);

  for p in (select (dp).geom from st_dumppoints(line) as dp) loop
    p3 = p2;
    p2 = p1;
    p1 = p;
    if p3 is null then continue; end if;
    raise notice 'ANGLE %', degrees(pi - st_angle(p1, p2, p2, p3));
  end loop;
end
$$ language plpgsql;

drop table if exists bends;
create table bends as (select * from detect_bends((select way from figures where name='fig3')));
