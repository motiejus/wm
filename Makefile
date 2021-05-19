WHERE ?= name='Visinčia' OR name='Šalčia' OR name='Nemunas'

.faux_filter-rivers: .faux_import-osm
	./db -v where="$(WHERE)" -f aggregate-rivers.sql
	touch $@

.faux_import-osm: lithuania-latest.osm.pbf .faux.db
	PGPASSWORD=osm osm2pgsql \
			   -c --multi-geometry \
			   -H 127.0.0.1 -d osm -U osm \
			   $<
	touch $@

.faux.db:
	./db start
	touch $@

lithuania-latest.osm.pbf:
	wget http://download.geofabrik.de/europe/lithuania-latest.osm.pbf
