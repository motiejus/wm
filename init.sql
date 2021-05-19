-- This file initializes tables for unit and integration tests.
-- ST_SimplifyWM, when dbgname is non-empty, expects `wm_debug` table to be
-- created.

-- to preview this somewhat conveniently in QGIS:
-- stage || '_' || name || ' gen:' || coalesce(gen, 'Ø') || ' nbend:' || lpad(nbend, 4, '0')
drop table if exists wm_debug;
create table wm_debug(stage text, name text, gen bigint, nbend bigint, way geometry, props jsonb);

-- Run ST_SimplifyWM in debug mode, so `wm_debug` is populated. That table
-- is used for geometric assertions later in the file.
drop table if exists wm_demo;
create table wm_demo (name text, i bigint, way geometry);
