OSM ?= lithuania-latest.osm.pbf
RIVERFILTER = Visinčia|Šalčia|Nemunas
SLIDES = slides-2021-03-29.pdf

GDB10LT ?= $(wildcard GDB10LT-static-*.zip)

# Max figure size (in meters) is when it's width is TEXTWIDTH_CM on scale 1:25k
SCALEDWIDTH = $(shell awk '/^TEXTWIDTH_CM/{print 25000/100*$$3}' layer2img.py)

##############################################################################
# These variables have to come before first use due to how macros are expanded
##############################################################################

NON_ARCHIVABLES = notes.txt referatui.txt slides-2021-03-29.txt
ARCHIVABLES = $(filter-out $(NON_ARCHIVABLES),$(shell git ls-files .))

LISTINGS = aggregate-rivers.sql wm.sql extract-and-generate

FIGURES = \
		  test-figures \
		  fig8-definition-of-a-bend \
		  fig8-elimination-gen1 \
		  fig8-elimination-gen2 \
		  fig8-elimination-gen3 \
		  fig5-gentle-inflection-before \
		  fig5-gentle-inflection-after \
		  inflection-1-gentle-inflection-before \
		  inflection-1-gentle-inflection-after \
		  fig6-selfcrossing \
		  selfcrossing-1 \
		  isolated-1-exaggerated

RIVERS = \
		 salvis-25k \
		 salvis-50k \
		 salvis-250k \
		 salvis-douglas-64-50k \
		 salvis-visvalingam-64-50k \
		 salvis-douglas-64-chaikin-50k \
		 salvis-visvalingam-64-chaikin-50k \
		 salvis-overlaid-douglas-64-chaikin-50k \
		 salvis-overlaid-visvalingam-64-chaikin-50k \
		 salvis-wm-250k \
		 salvis-wm-50k \
		 salvis-wm-50k-nw \
		 salvis-wm-50k-ne \
		 salvis-wm-overlaid-250k-zoom \
		 salvis-wm-gdr50 \
		 salvis-wm-gdr50-ne

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

.PHONY: visuals
visuals: .faux_visuals  # Generate visuals for paper (fast)

.PHONY: test-rivers
test-rivers: .faux_test-rivers ## Rivers tests (slow)

.PHONY: slides
slides: $(SLIDES)

.PHONY: refresh-rivers
refresh-rivers: refresh-rivers-10.sql refresh-rivers-50.sql refresh-rivers-250.sql ## Refresh river data from national datasets

###########################
# The report, quick version
###########################

mj-msc.pdf: mj-msc.tex version.inc.tex vars.inc.tex bib.bib \
	$(LISTINGS) $(addsuffix .pdf,$(FIGURES)) $(addsuffix .pdf,$(RIVERS))
	latexmk -shell-escape -pdf $<

############################
# Report's test dependencies
############################

define FIG_template
$(1).pdf: layer2img.py Makefile $(2)
	python3 ./layer2img.py --outfile=$(1).pdf \
		$$(if $$($(1)_WIDTHDIV),--widthdiv=$$($(1)_WIDTHDIV)) \
		$$(if $$($(1)_QUADRANT),--quadrant=$$($(1)_QUADRANT)) \
		$$(foreach i,1 2 3, \
			$$(if $$($(1)_$$(i)COLOR),--group$$(i)-color="$$($(1)_$$(i)COLOR)") \
			$$(if $$($(1)_$$(i)SELECT),--group$$(i)-select="$$($(1)_$$(i)SELECT)") \
			$$(if $$($(1)_$$(i)LINESTYLE),--group$$(i)-linestyle="$$($(1)_$$(i)LINESTYLE)") \
	)
endef
$(foreach fig,$(FIGURES),$(eval $(call FIG_template,$(fig),.faux_test)))
$(foreach fig,$(RIVERS), $(eval $(call FIG_template,$(fig),.faux_visuals)))

test-figures_1SELECT = wm_figures

fig8-definition-of-a-bend_1SELECT = wm_debug where name='fig8' AND stage='afigures' AND gen=1
fig8-definition-of-a-bend_2SELECT = wm_debug where name='fig8' AND stage='bbends-polygon' AND gen=1
fig8-definition-of-a-bend_3SELECT = wm_debug where name='fig8' AND stage='bbends-polygon' AND gen=1
fig8-definition-of-a-bend_3LINESTYLE = dotted

fig8-elimination-gen1_1SELECT = wm_debug where name='fig8' AND stage='afigures' AND gen=1
fig8-elimination-gen1_2SELECT = wm_debug where name='fig8' AND stage='bbends-polygon' AND gen=1
fig8-elimination-gen1_3SELECT = wm_debug where name='fig8' AND stage='bbends-polygon' AND gen=1
fig8-elimination-gen1_3LINESTYLE = dotted

fig8-elimination-gen2_1SELECT = wm_debug where name='fig8' AND stage='afigures' AND gen=2
fig8-elimination-gen2_2SELECT = wm_debug where name='fig8' AND stage='bbends-polygon' AND gen=2
fig8-elimination-gen2_3SELECT = wm_debug where name='fig8' AND stage='bbends-polygon' AND gen=2
fig8-elimination-gen2_3LINESTYLE = dotted
fig8-elimination-gen3_1SELECT = wm_debug where name='fig8' AND stage='bbends' AND gen=3
fig8-elimination-gen3_2SELECT = wm_debug where name='fig8' AND stage='bbends-polygon' AND gen=3
fig8-elimination-gen3_3SELECT = wm_debug where name='fig8' AND stage='bbends-polygon' AND gen=3
fig8-elimination-gen3_3LINESTYLE = dotted

fig5-gentle-inflection-before_WITHDIV = 2
fig5-gentle-inflection-before_1SELECT = wm_debug where name='fig5' AND stage='afigures' AND gen=1
fig5-gentle-inflection-before_2SELECT = wm_debug where name='fig5' AND stage='bbends-polygon' AND gen=1
fig5-gentle-inflection-before_3SELECT = wm_debug where name='fig5' AND stage='bbends-polygon' AND gen=1
fig5-gentle-inflection-before_3LINESTYLE = dotted
fig5-gentle-inflection-after_WITHDIV = 2
fig5-gentle-inflection-after_1SELECT = wm_debug where name='fig5' AND stage='cinflections' AND gen=1
fig5-gentle-inflection-after_2SELECT = wm_debug where name='fig5' AND stage='cinflections-polygon' AND gen=1
fig5-gentle-inflection-after_3SELECT = wm_debug where name='fig5' AND stage='cinflections-polygon' AND gen=1
fig5-gentle-inflection-after_3LINESTYLE = dotted

inflection-1-gentle-inflection-before_WIDTHDIV = 2
inflection-1-gentle-inflection-before_1SELECT = wm_debug where name='inflection-1' AND stage='afigures' AND gen=1
inflection-1-gentle-inflection-before_2SELECT = wm_debug where name='inflection-1' AND stage='bbends-polygon' AND gen=1
inflection-1-gentle-inflection-before_3SELECT = wm_debug where name='inflection-1' AND stage='bbends-polygon' AND gen=1
inflection-1-gentle-inflection-before_3LINESTYLE = dotted
inflection-1-gentle-inflection-after_WIDTHDIV = 2
inflection-1-gentle-inflection-after_1SELECT = wm_debug where name='inflection-1' AND stage='cinflections' AND gen=1
inflection-1-gentle-inflection-after_2SELECT = wm_debug where name='inflection-1' AND stage='cinflections-polygon' AND gen=1
inflection-1-gentle-inflection-after_3SELECT = wm_debug where name='inflection-1' AND stage='cinflections-polygon' AND gen=1
inflection-1-gentle-inflection-after_3LINESTYLE = dotted

fig6-selfcrossing_WIDTHDIV = 2
fig6-selfcrossing_1SELECT = wm_debug where name='fig6' AND stage='afigures' AND gen=1
fig6-selfcrossing_1LINESTYLE = dotted
fig6-selfcrossing_2SELECT = wm_debug where name='fig6' AND stage='dcrossings' AND gen=1
fig6-selfcrossing_3SELECT = wm_visuals where name='fig6-baseline'
fig6-selfcrossing_3COLOR = orange

selfcrossing-1_WIDTHDIV = 2
selfcrossing-1_1SELECT = wm_debug where name='selfcrossing-1' AND stage='afigures' AND gen=1
selfcrossing-1_1LINESTYLE = dotted
selfcrossing-1_2SELECT = wm_debug where name='selfcrossing-1' AND stage='dcrossings' AND gen=1
selfcrossing-1_3SELECT = wm_visuals where name='selfcrossing-1-baseline'
selfcrossing-1_3COLOR = orange

isolated-1-exaggerated_WIDTHDIV = 2
isolated-1-exaggerated_1SELECT = wm_debug where name='isolated-1' AND stage='afigures' AND gen=2
isolated-1-exaggerated_2SELECT = wm_debug where name='isolated-1' AND stage='afigures' AND gen=1
isolated-1-exaggerated_1COLOR = orange

salvis-25k_1SELECT = wm_visuals where name='salvis'
salvis-25k_WIDTHDIV = 1

salvis-50k_1SELECT = wm_visuals where name='salvis'
salvis-50k_WIDTHDIV = 2

salvis-250k_1SELECT = wm_visuals where name='salvis'
salvis-250k_WIDTHDIV = 10

salvis-douglas-64-50k_1SELECT = wm_visuals where name='salvis-douglas-64'
salvis-douglas-64-50k_WIDTHDIV = 2

salvis-visvalingam-64-50k_1SELECT = wm_visuals where name='salvis-visvalingam-64'
salvis-visvalingam-64-50k_WIDTHDIV = 2

salvis-douglas-64-chaikin-50k_2SELECT = wm_visuals where name='salvis-douglas-64-chaikin'
salvis-douglas-64-chaikin-50k_WIDTHDIV = 2

salvis-visvalingam-64-chaikin-50k_2SELECT = wm_visuals where name='salvis-visvalingam-64-chaikin'
salvis-visvalingam-64-chaikin-50k_WIDTHDIV = 2

salvis-overlaid-douglas-64-chaikin-50k_1SELECT = wm_visuals where name='salvis-douglas-64-chaikin'
salvis-overlaid-douglas-64-chaikin-50k_2SELECT = wm_visuals where name='salvis'
salvis-overlaid-douglas-64-chaikin-50k_1COLOR = orange
salvis-overlaid-douglas-64-chaikin-50k_WIDTHDIV = 2
salvis-overlaid-douglas-64-chaikin-50k_QUADRANT = 1

salvis-overlaid-visvalingam-64-chaikin-50k_1SELECT = wm_visuals where name='salvis-visvalingam-64-chaikin'
salvis-overlaid-visvalingam-64-chaikin-50k_2SELECT = wm_visuals where name='salvis'
salvis-overlaid-visvalingam-64-chaikin-50k_1COLOR = orange
salvis-overlaid-visvalingam-64-chaikin-50k_WIDTHDIV = 2
salvis-overlaid-visvalingam-64-chaikin-50k_QUADRANT = 1

salvis-wm-250k_1SELECT = wm_visuals where name='salvis-wm-220'
salvis-wm-250k_WIDTHDIV = 10

salvis-wm-50k_1SELECT = wm_visuals where name='salvis-wm-75'
salvis-wm-50k_2SELECT = wm_visuals where name='salvis'
salvis-wm-50k_1COLOR = orange

salvis-wm-50k-nw_1SELECT = wm_visuals where name='salvis-wm-75'
salvis-wm-50k-nw_2SELECT = wm_visuals where name='salvis'
salvis-wm-50k-nw_1COLOR = orange
salvis-wm-50k-nw_QUADRANT = 2

salvis-wm-50k-ne_1SELECT = wm_visuals where name='salvis-wm-75'
salvis-wm-50k-ne_2SELECT = wm_visuals where name='salvis'
salvis-wm-50k-ne_1COLOR = orange
salvis-wm-50k-ne_QUADRANT = 1

salvis-wm-overlaid-250k-zoom_1SELECT = wm_visuals where name='salvis-wm-220'
salvis-wm-overlaid-250k-zoom_2SELECT = wm_visuals where name='salvis'
salvis-wm-overlaid-250k-zoom_1COLOR = orange

salvis-wm-gdr50_1SELECT = wm_visuals where name='salvis-wm-75'
salvis-wm-gdr50_2SELECT = wm_visuals where name='salvis-gdr50'
salvis-wm-gdr50_3SELECT = wm_visuals where name='salvis'
salvis-wm-gdr50_1COLOR = orange
salvis-wm-gdr50_2COLOR = green

salvis-wm-gdr50-ne_1SELECT = wm_visuals where name='salvis-wm-75'
salvis-wm-gdr50-ne_2SELECT = wm_visuals where name='salvis-gdr50'
salvis-wm-gdr50-ne_3SELECT = wm_visuals where name='salvis'
salvis-wm-gdr50-ne_1COLOR = orange
salvis-wm-gdr50-ne_2COLOR = green
salvis-wm-gdr50-ne_QUADRANT = 1


.faux_db_pre: db init.sql
	bash db start
	bash db -f init.sql
	touch $@

.faux_db: rivers-10.sql rivers-50.sql rivers-250.sql
	bash db $(addprefix -f ,$^)
	touch $@
.faux_db: .EXTRA_PREREQS = .faux_db_pre

.faux_test: test.sql wm.sql .faux_db
	bash db -f $<
	touch $@

.faux_visuals: visuals.sql .faux_test
	bash db -v scaledwidth=$(SCALEDWIDTH) -f $<
	touch $@

.faux_test-rivers: test-rivers.sql wm.sql Makefile .faux_db
	bash db -f $<
	touch $@

################################
# Report's non-test dependencies
################################

REF = $(shell git describe --abbrev=12 --always --dirty)
version.inc.tex: Makefile $(shell git rev-parse --git-dir 2>/dev/null)
	TZ=UTC date '+\gdef\VCDescribe{%F (revision $(REF))}%' > $@

vars.inc.tex: vars.awk wm.sql Makefile
	awk -f $< wm.sql

###############
# Misc commands
###############

slides-2021-03-29.pdf: slides-2021-03-29.txt
	pandoc -t beamer -i $< -o $@

dump-debug_wm.sql.xz:
	docker exec -ti wm-mj pg_dump -Uosm osm -t wm_devug | xz -v > $@

release.zip: mj-msc.tex mj-msc.bbl version.inc.tex vars.inc.tex \
	$(addsuffix .pdf,$(FIGURES)) $(addsuffix .pdf,$(RIVERS)) \
	$(shell git ls-files .)
	-rm $@
	mkdir -p .tmp; touch .tmp/editorial-version
	zip $@ $^
	zip $@ -j .tmp/editorial-version

mj-msc.bbl: mj-msc.tex bib.bib
	biber mj-msc

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
	-bash db stop
	-rm -r .faux_test .faux_aggregate-rivers .faux_test-rivers .faux_visuals \
		.faux_db .faux_db_pre version.inc.tex vars.inc.tex version.aux \
		version.fdb_latexmk _minted-mj-msc .tmp \
		$(shell git ls-files -o mj-msc*) \
		$(addsuffix .pdf,$(FIGURES)) \
		$(addsuffix .pdf,$(RIVERS)) \
		$(SLIDES)

.PHONY: clean-tables
clean-tables: ## Remove tables created during unit or rivers tests
	bash db -c '\dt wm_*' | awk '/_/{print "drop table "$$3";"}' | bash db -f -
	-rm .faux_db

.PHONY: help
help: ## Print this help message
	@awk -F':.*?## ' '/^[a-z0-9.-]*: *.*## */{printf "%-18s %s\n",$$1,$$2}' \
		$(MAKEFILE_LIST)

.PHONY: wc
wc: mj-msc.pdf ## Character and page count
	@pdftotext $< - | \
		awk '/\yReferences\y/{exit}; {print}' | \
		tr -d '[:space:]' | wc -c | \
		awk '{printf("Chars: %d, pages: %.1f\n", $$1, $$1/1500)}'

define refresh_rivers_template
.PHONY: refresh-$(1)
refresh-$(1): aggregate-rivers.sql gdr2pgsql .faux_db_pre
	@if [ ! -f "$$($(2))" ]; then \
		echo "ERROR: $(2)-static-*.zip not found. Run env $(2)=<...>"; \
		exit 1; \
	fi
	./gdr2pgsql "$$($(2))" "$(3)" "$(RIVERFILTER)" "$(1)"
endef

$(eval $(call rivers_template,rivers-10.sql,GDB10LT,wm_rivers))
$(eval $(call rivers_template,rivers-50.sql,GDR50LT,wm_rivers_50))
$(eval $(call rivers_template,rivers-250.sql,GDR250LT,wm_rivers_250))
