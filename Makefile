SOURCE ?= lithuania-latest.osm.pbf
WHERE ?= name='Visinčia' OR name='Šalčia' OR name='Nemunas' OR name='Žeimena' OR name='Lakaja'
#WHERE ?= name='Žeimena' OR name='Lakaja'
SLIDES = slides-2021-03-29.pdf

NON_ARCHIVABLES = notes.txt referatui.txt slides-2021-03-29.txt
ARCHIVABLES = $(filter-out $(NON_ARCHIVABLES),$(shell git ls-files .))

FIGURES = test-figures \
					fig6-self-crossing-before \
					fig6-self-crossing-after \
					fig8-definition-of-a-bend \
					fig5-gentle-inflection-before \
					fig5-gentle-inflection-after \
					inflection-1-gentle-inflection-before \
					inflection-1-gentle-inflection-after

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
		minted-mj-msc \
		$(shell git ls-files -o mj-msc*) \
		$(addsuffix .pdf,$(FIGURES)) \
		$(SLIDES)

.PHONY: clean-tables
clean-tables:
	for t in $$(./db -c '\dt' | awk '/\ywm_\w+\y/{print $$3}'); do \
		./db -c "drop table $$t"; \
	done
	-rm .faux_test

.PHONY: slides
slides: $(SLIDES)

mj-msc.pdf: mj-msc.tex version.inc.tex vars.inc.tex bib.bib $(addsuffix .pdf,$(FIGURES))
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

define FIG_template
$(1).pdf: layer2img.py Makefile .faux_test
	python ./layer2img.py \
		--outfile=$(1).pdf \
		$$(if $$($(1)_WIDTHDIV),--widthdiv=$$($(1)_WIDTHDIV)) \
		$$(foreach i,1 2 3, \
			$$(if $$($(1)_CMAP$$(i)),--group$$(i)-cmap="$$($(1)_CMAP$$(i))") \
			$$(if $$($(1)_SELECT$$(i)),--group$$(i)-select="$$($(1)_SELECT$$(i))") \
			$$(if $$($(1)_LINESTYLE$$(i)),--group$$(i)-linestyle="$$($(1)_LINESTYLE$$(i))") \
	)
endef

$(foreach fig,$(FIGURES),$(eval $(call FIG_template,$(fig))))

test-figures_SELECT1 = wm_figures

fig8-definition-of-a-bend_SELECT1 = wm_debug where name='fig8' AND stage='bbends' AND gen=1
fig8-definition-of-a-bend_CMAP2 = 1
fig8-definition-of-a-bend_SELECT2 = wm_debug where name='fig8' AND stage='bbends-polygon' AND gen=1

fig5-gentle-inflection-before_WITHDIV = 2
fig5-gentle-inflection-before_SELECT1 = wm_debug where name='fig5' AND stage='bbends' AND gen=1
fig5-gentle-inflection-before_CMAP2 = 1
fig5-gentle-inflection-before_SELECT2 = wm_debug where name='fig5' AND stage='bbends-polygon' AND gen=1
fig5-gentle-inflection-after_WITHDIV = 2
fig5-gentle-inflection-after_SELECT1 = wm_debug where name='fig5' AND stage='cinflections' AND gen=1
fig5-gentle-inflection-after_SELECT2 = wm_debug where name='fig5' AND stage='cinflections-polygon' AND gen=1
fig5-gentle-inflection-after_CMAP2 = 1

inflection-1-gentle-inflection-before_WIDTHDIV = 2
inflection-1-gentle-inflection-before_SELECT1 = wm_debug where name='inflection-1' AND stage='bbends' AND gen=1
inflection-1-gentle-inflection-before_SELECT2 = wm_debug where name='inflection-1' AND stage='bbends-polygon' AND gen=1
inflection-1-gentle-inflection-before_CMAP2 = 1
inflection-1-gentle-inflection-after_WIDTHDIV = 2
inflection-1-gentle-inflection-after_SELECT1 = wm_debug where name='inflection-1' AND stage='cinflections' AND gen=1
inflection-1-gentle-inflection-after_SELECT2 = wm_debug where name='inflection-1' AND stage='cinflections-polygon' AND gen=1
inflection-1-gentle-inflection-after_CMAP2 = 1

fig6-self-crossing-before_WIDTHDIV = 4
fig6-self-crossing-before_SELECT1 = wm_debug where name='fig6' AND stage='bbends' AND gen=1
fig6-self-crossing-before_SELECT2 = wm_visuals where name='fig6-baseline'
fig6-self-crossing-before_SELECT3 = wm_visuals where name='fig6-newline'
fig6-self-crossing-before_LINESTYLE2 = dashed
fig6-self-crossing-before_LINESTYLE3 = dashed
fig6-self-crossing-after_WIDTHDIV = 4
fig6-self-crossing-after_SELECT1 = wm_debug where name='fig6' AND stage='dcrossings' AND gen=1

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
