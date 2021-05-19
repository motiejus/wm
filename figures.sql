drop table if exists figures;
create table figures (name text, way geometry);

insert into figures (name, way) values ('fig3', ST_GeomFromText('LINESTRING(0 0, 12 0, 13 4, 20 2, 20 0, 32 0, 33 10, 38 16, 43 15, 44 10, 44 0, 60 0)'));
