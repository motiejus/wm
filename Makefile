SOURCE ?= lithuania-latest.osm.pbf
WHERE ?= name='Visinčia' OR name='Šalčia' OR name='Nemunas'

SLIDY_PATH= /usr/share/xml/docbook/stylesheet/docbook-xsl/slides/slidy
ifneq ($(wildcard $(SLIDY_PATH)/.*),)
SLIDY_ARGS = -V slidy-url=$(SLIDY_PATH)
endif

.PHONY: test
test: tests.sql .faux.db
	./db -f tests.sql

.PHONY: test-integration
test-integration: .faux_filter-rivers
	./db -f tests-integration.sql

.PHONY: clean
clean:
	-./db stop
	-rm .faux_filter-rivers .faux_import-osm .faux.db

.PHONY: clean-tables
clean-tables:
	for t in $$(./db -c '\dt' | awk '/demo|debug|integ/{print $$3}'); do \
		./db -c "drop table $$t"; \
	done

.PHONY: slides
slides: slides-2021-03-29.pdf slides-2021-03-29.html

slides-2021-03-29.pdf: slides-2021-03-29.txt
	pandoc -t beamer -i $< -o $@

slides-2021-03-29.html: slides-2021-03-29.txt
	pandoc --verbose -t slidy --self-contained $< -o $@ $(SLIDY_ARGS)

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
