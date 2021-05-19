SOURCE ?= lithuania-latest.osm.pbf
WHERE ?= name='Visinčia' OR name='Šalčia' OR name='Nemunas' OR name='Žeimena' OR name='Lakaja'
#WHERE ?= name='Žeimena' OR name='Lakaja'
SLIDES = slides-2021-03-29.pdf

NON_ARCHIVABLES = notes.txt referatui.txt slides-2021-03-29.txt
ARCHIVABLES = $(filter-out $(NON_ARCHIVABLES),$(shell git ls-files .))

.PHONY: test
test: .faux_test

.PHONY: test-integration
test-integration: .faux_filter-rivers
	./db -f tests-integration.sql

.PHONY: clean
clean:
	-./db stop
	-rm -r .faux_test .faux_filter-rivers .faux_import-osm .faux_db \
		version.tex test-figures.pdf _minted-mj-msc \
		$(shell git ls-files -o mj-msc*) \
		$(SLIDES)

.PHONY: clean-tables
clean-tables:
	for t in $$(./db -c '\dt' | awk '/\ywm_\w+\y/{print $$3}'); do \
		./db -c "drop table $$t"; \
	done
	-rm .faux_test

.PHONY: slides
slides: $(SLIDES)

mj-msc.pdf: mj-msc.tex test-figures.pdf version.tex bib.bib
	latexmk -shell-escape -g -pdf $<

mj-msc-full.pdf: mj-msc.pdf version.tex $(ARCHIVABLES)
	cp $< .tmp-$@
	for f in $^; do \
		if [ "$$f" = "$<" ]; then continue; fi; \
		pdfattach .tmp-$@ $$f .tmp2-$@; \
		mv .tmp2-$@ .tmp-$@; \
	done
	mv .tmp-$@ $@

test-figures.pdf: layer2img.py .faux_test
	python ./layer2img.py --group1-table=wm_figures --group1-arrows=yes --outfile=$@

.faux_test: tests.sql wm.sql .faux_db
	./db -f tests.sql
	touch $@

.faux_filter-rivers: .faux_import-osm Makefile
	./db -v where="$(WHERE)" -f aggregate-rivers.sql
	touch $@

.faux_import-osm: $(SOURCE) .faux_db
	PGPASSWORD=osm osm2pgsql \
			   -c --multi-geometry \
			   -H 127.0.0.1 -d osm -U osm \
			   $<
	touch $@

.faux_db:
	./db start
	touch $@

$(SOURCE):
	wget http://download.geofabrik.de/europe/$@

REF = $(shell git describe --abbrev=12 --always --dirty)
version.tex: Makefile $(shell git rev-parse --git-dir 2>/dev/null)
	TZ=UTC date '+\gdef\VCDescribe{%F ($(REF))}%' > $@

slides-2021-03-29.pdf: slides-2021-03-29.txt
	pandoc -t beamer -i $< -o $@

dump-debug_wm.sql.xz:
	docker exec -ti wm-mj pg_dump -Uosm osm -t debug_wm | xz -v > $@
