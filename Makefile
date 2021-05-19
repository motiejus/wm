SOURCE ?= lithuania-latest.osm.pbf
WHERE ?= name='Visinčia' OR name='Šalčia' OR name='Nemunas'

SLIDES = slides-2021-03-29.pdf
NON_ARCHIVABLES = notes.txt referatui.txt slides-2021-03-29.txt
ARCHIVABLES = $(filter-out $(NON_ARCHIVABLES),$(shell git ls-files .))

.PHONY: test
test: tests.sql .faux.db
	./db -f tests.sql

.PHONY: test-integration
test-integration: .faux_filter-rivers
	./db -f tests-integration.sql

.PHONY: clean
clean:
	-./db stop
	-rm .faux_filter-rivers .faux_import-osm .faux.db $(SLIDES)

.PHONY: clean-tables
clean-tables:
	for t in $$(./db -c '\dt' | awk '/demo|debug|integ/{print $$3}'); do \
		./db -c "drop table $$t"; \
	done

.PHONY: slides
slides: $(SLIDES)

mj-msc.pdf: mj-msc.tex version.tex bib.bib 
	latexmk -shell-escape -g -pdf $<

mj-msc-all.pdf: mj-msc.pdf version.tex $(ARCHIVABLES)
	cp $< .tmp-$@
	for f in $^; do \
		if [ "$$f" = "$<" ]; then continue; fi; \
		pdfattach .tmp-$@ $$f .tmp2-$@; \
		mv .tmp2-$@ .tmp-$@; \
	done
	mv .tmp-$@ $@

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

REF = $(shell git describe --tags --dirty)
version.tex: $(shell git rev-parse --show-toplevel)/.git
	( \
		date '+\gdef\GeneratedAt{%F %T %Z}%'; \
		printf '\gdef\VCDescribe{%s}%%\n' $(REF); \
	) > $@
