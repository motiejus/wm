SOURCE ?= lithuania-latest.osm.pbf
WHERE ?= name='Visinčia' OR name='Šalčia' OR name='Nemunas'

.PHONY: test
test: tests.sql .faux.db
	./db -f tests.sql

.PHONY: integration-test
integration-test: .faux_filter_rivers
	./db -f integration-tests.sql

.faux_filter-rivers: .faux_import-osm
	./db -v where="$(WHERE)" -f aggregate-rivers.sql
	touch $@

.faux_import-osm: $(SOURCE) .faux.db
	PGPASSWORD=osm osm2pgsql \
			   -c --multi-geometry \
			   -H 127.0.0.1 -d osm -U osm \
			   $<
	touch $@

.faux.db:
	./db start
	touch $@

$(SOURCE):
	wget http://download.geofabrik.de/europe/$@
