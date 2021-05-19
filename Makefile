# HACK HACK
EMPTY :=
SPACE := $(EMPTY) $(EMPTY)

RIVERS ?= Visinčia Šalčia Žeimena Lakaja

.faux_filter-rivers: .faux_import-osm
	./filter-rivers-query.awk $(RIVERS) | ./db -f -
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
