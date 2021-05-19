SOURCE ?= lithuania-latest.osm.pbf
WHERE ?= name='Visinčia' OR name='Šalčia' OR name='Nemunas' OR name='Žeimena' OR name='Lakaja'
#WHERE ?= name like '%'
SLIDES = slides-2021-03-29.pdf

##############################################################################
# These variables have to come before first use due to how macros are expanded
##############################################################################

NON_ARCHIVABLES = notes.txt referatui.txt slides-2021-03-29.txt
ARCHIVABLES = $(filter-out $(NON_ARCHIVABLES),$(shell git ls-files .))

FIGURES = test-figures \
					fig8-definition-of-a-bend \
					fig5-gentle-inflection-before \
					fig5-gentle-inflection-after \
					inflection-1-gentle-inflection-before \
					inflection-1-gentle-inflection-after \
					fig6-self-crossing-before \
					fig6-self-crossing-after

#################################
# The thesis, publishable version
#################################

mj-msc-full.pdf: mj-msc.pdf version.inc.tex $(ARCHIVABLES) ## Thesis for publishing
	cp $< .tmp-$@
	for f in $^; do \
		if [ "$$f" = "$<" ]; then continue; fi; \
		pdfattach .tmp-$@ $$f .tmp2-$@; \
		mv .tmp2-$@ .tmp-$@; \
	done
	mv .tmp-$@ $@

###############################
# Auxiliary targets for humans
###############################

.PHONY: test
test: .faux_test ## Unit tests (fast)

.PHONY: test-integration
test-integration: .faux_test-integration ## Integration tests (slow)

.PHONY: slides
slides: $(SLIDES)

###########################
# The report, quick version
###########################

mj-msc.pdf: mj-msc.tex version.inc.tex vars.inc.tex bib.bib $(addsuffix .pdf,$(FIGURES))
	latexmk -shell-escape -g -pdf $<

############################
# Report's test dependencies
############################

define FIG_template
$(1).pdf: layer2img.py Makefile .faux_test
	python ./layer2img.py --outfile=$(1).pdf \
		$$(if $$($(1)_WIDTHDIV),--widthdiv=$$($(1)_WIDTHDIV)) \
		$$(foreach i,1 2 3, \
			$$(if $$($(1)_$$(i)CMAP),--group$$(i)-cmap="$$($(1)_$$(i)CMAP)") \
			$$(if $$($(1)_$$(i)SELECT),--group$$(i)-select="$$($(1)_$$(i)SELECT)") \
			$$(if $$($(1)_$$(i)LINESTYLE),--group$$(i)-linestyle="$$($(1)_$$(i)LINESTYLE)") \
	)
endef
$(foreach fig,$(FIGURES),$(eval $(call FIG_template,$(fig))))

test-figures_1SELECT = wm_figures

fig8-definition-of-a-bend_1SELECT = wm_debug where name='fig8' AND stage='bbends' AND gen=1
fig8-definition-of-a-bend_2CMAP = 1
fig8-definition-of-a-bend_2SELECT = wm_debug where name='fig8' AND stage='bbends-polygon' AND gen=1

fig5-gentle-inflection-before_WITHDIV = 2
fig5-gentle-inflection-before_1SELECT = wm_debug where name='fig5' AND stage='bbends' AND gen=1
fig5-gentle-inflection-before_2CMAP = 1
fig5-gentle-inflection-before_2SELECT = wm_debug where name='fig5' AND stage='bbends-polygon' AND gen=1
fig5-gentle-inflection-after_WITHDIV = 2
fig5-gentle-inflection-after_1SELECT = wm_debug where name='fig5' AND stage='cinflections' AND gen=1
fig5-gentle-inflection-after_2SELECT = wm_debug where name='fig5' AND stage='cinflections-polygon' AND gen=1
fig5-gentle-inflection-after_2CMAP = 1

inflection-1-gentle-inflection-before_WIDTHDIV = 2
inflection-1-gentle-inflection-before_1SELECT = wm_debug where name='inflection-1' AND stage='bbends' AND gen=1
inflection-1-gentle-inflection-before_2SELECT = wm_debug where name='inflection-1' AND stage='bbends-polygon' AND gen=1
inflection-1-gentle-inflection-before_2CMAP = 1
inflection-1-gentle-inflection-after_WIDTHDIV = 2
inflection-1-gentle-inflection-after_1SELECT = wm_debug where name='inflection-1' AND stage='cinflections' AND gen=1
inflection-1-gentle-inflection-after_2SELECT = wm_debug where name='inflection-1' AND stage='cinflections-polygon' AND gen=1
inflection-1-gentle-inflection-after_2CMAP = 1

fig6-self-crossing-before_WIDTHDIV = 4
fig6-self-crossing-before_1SELECT = wm_debug where name='fig6' AND stage='bbends' AND gen=1
fig6-self-crossing-before_2SELECT = wm_visuals where name='fig6-baseline'
fig6-self-crossing-before_2LINESTYLE = dotted
fig6-self-crossing-before_3SELECT = wm_visuals where name='fig6-newline'
fig6-self-crossing-after_WIDTHDIV = 4
fig6-self-crossing-after_1SELECT = wm_debug where name='fig6' AND stage='dcrossings' AND gen=1


.faux_test-integration: tests-integration.sql wm.sql .faux_aggregate-rivers
	./db -f $<
	touch $@

.faux_test: tests.sql wm.sql .faux_db
	./db -f $<
	touch $@

.faux_db: db init.sql
	./db start
	./db -f init.sql
	touch $@

$(SOURCE):
	wget http://download.geofabrik.de/europe/$@

.faux_aggregate-rivers: aggregate-rivers.sql .faux_import-osm Makefile
	./db -v where="$(WHERE)" -f $<
	touch $@

.faux_import-osm: $(SOURCE) .faux_db
	PGPASSWORD=osm osm2pgsql -c --multi-geometry -H 127.0.0.1 -d osm -U osm $<
	touch $@

################################
# Report's non-test dependencies
################################

REF = $(shell git describe --abbrev=12 --always --dirty)
version.inc.tex: Makefile $(shell git rev-parse --git-dir 2>/dev/null)
	TZ=UTC date '+\gdef\VCDescribe{%F ($(REF))}%' > $@

vars.inc.tex: vars.awk wm.sql Makefile
	awk -f $< wm.sql

###############
# Misc commands
###############

slides-2021-03-29.pdf: slides-2021-03-29.txt
	pandoc -t beamer -i $< -o $@

dump-debug_wm.sql.xz:
	docker exec -ti wm-mj pg_dump -Uosm osm -t debug_wm | xz -v > $@

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

.PHONY: clean
clean: ## Clean the current working directory
	-./db stop
	-rm -r .faux_test .faux_aggregate-rivers .faux_import-osm .faux_db \
		version.inc.tex vars.inc.tex version.aux version.fdb_latexmk \
		_minted-mj-msc \
		$(shell git ls-files -o mj-msc*) \
		$(addsuffix .pdf,$(FIGURES)) \
		$(SLIDES)

.PHONY: clean-tables
clean-tables: ## Remove tables created during unit or integration tests
	./db -c '\dt wm_*' | awk '/_/{print "drop table "$$3";"}' | ./db -f -
	-rm .faux_db

.PHONY: help
help: ## Print this help message
	@awk -F':.*?## ' '/^[a-z0-9.-]*: *.*## */{printf "%-18s %s\n",$$1,$$2}' $(MAKEFILE_LIST)
