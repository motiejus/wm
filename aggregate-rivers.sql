/* Aggregates rivers by name and proximity. */
drop function if exists aggregate_rivers;
create function aggregate_rivers() returns table(osm_id bigint, name text, way geometry) as $$
declare
  c record;
  cc record;
  changed boolean;
begin
  while (select count(1) from agg_tmp_objects) > 0 loop
    select * from agg_tmp_objects limit 1 into c;
    delete from agg_tmp_objects a where a.osm_id = c.osm_id;
    changed = true;
    while changed loop
      changed = false;
      for cc in (select * from agg_tmp_objects a where a.name = c.name and st_dwithin(a.way, c.way, 500)) loop
        c.way = st_linemerge(st_union(c.way, cc.way));
        delete from agg_tmp_objects a where a.osm_id = cc.osm_id;
        changed = true;
      end loop;
    end loop; -- while changed
    return query select c.osm_id, c.name, c.way;
  end loop; -- count(1) from agg_tmp_objects > 0
  return;
end
$$ language plpgsql;

create temporary table agg_tmp_objects (osm_id bigint, name text, way geometry);
create index agg_tmp_objects_id on agg_tmp_objects(osm_id);
create index agg_tmp_objects_gix on agg_tmp_objects using gist(way) include(name);

insert into agg_tmp_objects
  select p.osm_id, p.name, p.way from planet_osm_line p
    where waterway in ('river', 'stream', 'canal') and :where;

drop table if exists agg_rivers;
create table agg_rivers as (select * from aggregate_rivers());
drop table agg_tmp_objects;
