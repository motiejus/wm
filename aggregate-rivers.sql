/* Aggregates rivers by name and proximity. */
drop function if exists aggregate_rivers;
create function aggregate_rivers() returns table(
  id integer,
  name text,
  way geometry
) as $$
declare
  c record;
  cc record;
  changed boolean;
begin
  while (select count(1) from wm_rivers_tmp) > 0 loop
    select * from wm_rivers_tmp limit 1 into c;
    delete from wm_rivers_tmp a where a.id = c.id;
    changed = true;
    while changed loop
      changed = false;
      for cc in (
        select * from wm_rivers_tmp a where
          a.name = c.name and
          st_dwithin(a.way, c.way, 500)
        ) loop
        c.way = st_linemerge(st_union(c.way, cc.way));
        delete from wm_rivers_tmp a where a.id = cc.id;
        changed = true;
      end loop;
    end loop; -- while changed
    return query select c.id, c.name, c.way;
  end loop; -- count(1) from wm_rivers_tmp > 0
  return;
end
$$ language plpgsql;

drop index if exists wm_rivers_tmp_id;
drop index if exists wm_rivers_tmp_gix;
drop table if exists wm_rivers_tmp;
create temporary table wm_rivers_tmp (id serial, name text, way geometry);
create index wm_rivers_tmp_id on wm_rivers_tmp(id);
create index wm_rivers_tmp_gix on wm_rivers_tmp using gist(way) include(name);

insert into wm_rivers_tmp (name, way)
  select p.vardas as name, p.shape as way from :srctable p;

drop table if exists :dsttable;
create table :dsttable as (
  select * from aggregate_rivers() where st_length(way) >= 50000
);
drop table wm_rivers_tmp;
