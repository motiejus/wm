SOURCE ?= lithuania-latest.osm.pbf
WHERE ?= name='Visinčia' OR name='Šalčia' OR name='Nemunas' OR name='Žeimena' OR name='Lakaja'
#WHERE ?= name='Žeimena' OR name='Lakaja'
SLIDES = slides-2021-03-29.pdf

NON_ARCHIVABLES = notes.txt referatui.txt slides-2021-03-29.txt
ARCHIVABLES = $(filter-out $(NON_ARCHIVABLES),$(shell git ls-files .))
FIGURES = fig8-definition-of-a-bend.pdf \
		  fig5-gentle-inflection-before.pdf \
		  fig5-gentle-inflection-after.pdf \
		  inflection-1-gentle-inflection-before.pdf \
		  inflection-1-gentle-inflection-after.pdf \
			fig6-self-crossing-before.pdf \
			fig6-self-crossing-after.pdf

.PHONY: test
test: .faux_test

.PHONY: test-integration
test-integration: .faux_filter-rivers
	./db -f tests-integration.sql

.PHONY: clean
clean:
	-./db stop
	-rm -r .faux_test .faux_filter-rivers .faux_import-osm .faux_db \
		version.inc.tex vars.inc.tex version.aux version.fdb_latexmk \
		test-figures.pdf _minted-mj-msc \
		$(shell git ls-files -o mj-msc*) \
		$(SLIDES) \
		$(FIGURES)

.PHONY: clean-tables
clean-tables:
	for t in $$(./db -c '\dt' | awk '/\ywm_\w+\y/{print $$3}'); do \
		./db -c "drop table $$t"; \
	done
	-rm .faux_test

.PHONY: slides
slides: $(SLIDES)

mj-msc.pdf: mj-msc.tex test-figures.pdf version.inc.tex vars.inc.tex bib.bib $(FIGURES)
	latexmk -shell-escape -g -pdf $<

mj-msc-gray.pdf: mj-msc.pdf
	gs \
		-sOutputFile=$@ \
		-sDEVICE=pdfwrite \
		-sColorConversionStrategy=Gray \
		-dProcessColorModel=/DeviceGray \
		-dCompatibilityLevel=1.4 \
		-dNOPAUSE \
		-dBATCH \
		$<

mj-msc-full.pdf: mj-msc.pdf version.inc.tex $(ARCHIVABLES)
	cp $< .tmp-$@
	for f in $^; do \
		if [ "$$f" = "$<" ]; then continue; fi; \
		pdfattach .tmp-$@ $$f .tmp2-$@; \
		mv .tmp2-$@ .tmp-$@; \
	done
	mv .tmp-$@ $@

test-figures.pdf: layer2img.py .faux_test
	python ./layer2img.py --group1-table=wm_figures --outfile=$@

fig8-definition-of-a-bend.pdf: layer2img.py Makefile .faux_test
	python ./layer2img.py \
		--group1-table=wm_debug \
		--group1-where="name='fig8' AND stage='bbends' AND gen=1" \
		--group2-cmap=1 \
		--group2-table=wm_debug \
		--group2-where="name='fig8' AND stage='bbends-polygon' AND gen=1" \
		--outfile=$@

fig5-gentle-inflection-before.pdf: layer2img.py Makefile .faux_test
	python ./layer2img.py \
		--widthdiv=2 \
		--group1-table=wm_debug \
		--group1-where="name='fig5' AND stage='bbends' AND gen=1" \
		--group2-cmap=1 \
		--group2-table=wm_debug \
		--group2-where="name='fig5' AND stage='bbends-polygon' AND gen=1" \
		--outfile=$@

fig5-gentle-inflection-after.pdf: layer2img.py Makefile .faux_test
	python ./layer2img.py \
		--widthdiv=2 \
		--group1-table=wm_debug \
		--group1-where="name='fig5' AND stage='cinflections' AND gen=1" \
		--group2-cmap=1 \
		--group2-table=wm_debug \
		--group2-where="name='fig5' AND stage='cinflections-polygon' AND gen=1" \
		--outfile=$@

inflection-1-gentle-inflection-before.pdf: layer2img.py Makefile .faux_test
	python ./layer2img.py \
		--widthdiv=2 \
		--group1-table=wm_debug \
		--group1-where="name='inflection-1' AND stage='bbends' AND gen=1" \
		--group2-cmap=1 \
		--group2-table=wm_debug \
		--group2-where="name='inflection-1' AND stage='bbends-polygon' AND gen=1" \
		--outfile=$@

inflection-1-gentle-inflection-after.pdf: layer2img.py Makefile .faux_test
	python ./layer2img.py \
		--widthdiv=2 \
		--group1-table=wm_debug \
		--group1-where="name='inflection-1' AND stage='cinflections' AND gen=1" \
		--group2-cmap=1 \
		--group2-table=wm_debug \
		--group2-where="name='inflection-1' AND stage='cinflections-polygon' AND gen=1" \
		--outfile=$@

fig6-self-crossing-before.pdf: layer2img.py Makefile .faux_test
	python ./layer2img.py \
		--widthdiv=4 \
		--group1-table=wm_debug \
		--group1-where="name='fig6' AND stage='bbends' AND gen=1" \
		--group2-table=wm_visuals \
		--group2-where="name='fig6-baseline'" \
		--outfile=$@

fig6-self-crossing-after.pdf: layer2img.py Makefile .faux_test
	python ./layer2img.py \
		--widthdiv=4 \
		--group1-table=wm_debug \
		--group1-where="name='fig6' AND stage='dcrossings' AND gen=1" \
		--outfile=$@

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
version.inc.tex: Makefile $(shell git rev-parse --git-dir 2>/dev/null)
	TZ=UTC date '+\gdef\VCDescribe{%F ($(REF))}%' > $@

vars.inc.tex: vars.awk wm.sql Makefile
	awk -f $< wm.sql

slides-2021-03-29.pdf: slides-2021-03-29.txt
	pandoc -t beamer -i $< -o $@

dump-debug_wm.sql.xz:
	docker exec -ti wm-mj pg_dump -Uosm osm -t debug_wm | xz -v > $@
