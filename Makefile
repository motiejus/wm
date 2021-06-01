# River selector (GNU Awk syntax) to refresh-rivers target.
RIVERFILTER = Visinčia|Šalčia|Nemunas

# Max figure size (in meters) is when it's width is TEXTWIDTH_CM on scale 1:25k
SCALEDWIDTH = $(shell awk '/^TEXTWIDTH_CM/{print 25000/100*$$3}' layer2img.py)
SLIDES_IN = slides-2021-03-29.txt slides-2021-06-02.tex
SLIDES = slides-2021-03-29 slides-2021-06-02
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

FIGURES_SLIDES += isolated-1-before \
				  isolated-1-after

RIVERS = \
		 salvis-25k \
		 salvis-2x50k \
		 salvis-250k-10x \
		 salvis-grpk250-2x \
		 salvis-dp64-2x50k \
		 salvis-vw64-2x50k \
		 salvis-dpchaikin64-2x50k \
		 salvis-vwchaikin64-2x50k \
		 salvis-overlaid-dpchaikin64-2x50k \
		 salvis-overlaid-vwchaikin64-2x50k \
		 salvis-wm220-10x \
		 salvis-wm220-2x \
		 salvis-wm-overlaid-250k-zoom \
		 salvis-wm220

RIVERS_SLIDES += salvis-dp64overlaid-2x50k \
				 salvis-dpchaikin64overlaid-2x50k

################################################################################
# FIGURES
################################################################################
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

isolated-1-before_1SELECT = wm_debug where name='isolated-1' AND stage='afigures' AND gen=1
isolated-1-before_2SELECT = wm_debug where name='isolated-1' AND stage='afigures' AND gen=2
isolated-1-before_2LINESTYLE = invisible
isolated-1-before_WIDTHDIV = 2
isolated-1-after_1SELECT = wm_debug where name='isolated-1' AND stage='afigures' AND gen=2
isolated-1-after_1COLOR = orange
isolated-1-after_WIDTHDIV = 2


################################################################################
# 250K
################################################################################

salvis-wm220-250k-2x_1SELECT = wm_visuals where name='salvis-wm220'
salvis-wm220-250k-2x_WIDTHDIV = 2

salvis-wm220-250k-10x_1SELECT = wm_visuals where name='salvis-wm220'
salvis-wm220-250k-10x_WIDTHDIV = 10

salvis-250k-10x_1SELECT = wm_visuals where name='salvis-grpk10'
salvis-250k-10x_WIDTHDIV = 10

salvis-wm-overlaid-250k-zoom_1SELECT = wm_visuals where name='salvis-wm220'
salvis-wm-overlaid-250k-zoom_2SELECT = wm_visuals where name='salvis-grpk10'
salvis-wm-overlaid-250k-zoom_1COLOR = orange

salvis-grpk250-2x_1SELECT = wm_visuals where name='salvis-grpk250'
salvis-grpk250-2x_WIDTHDIV = 2

################################################################################
# 50K
################################################################################

label_wm75 = Wang--Müller 1:\numprint{50000}
label_wm220 = Wang--Müller 1:\numprint{250000}
label_vw64 = Visvalingam--Whyatt
label_dp64 = Douglas \& Peucker
label_grpk10 = GRPK 1:\numprint{10000}
label_grpk50 = GRPK 1:\numprint{50000}
label_vwchaikin64 = $(label_vw64) and Chaikin
label_dpchaikin64 = $(label_dp64) and Chaikin
label_vwchaikin64lt = $(label_vw64) ir Chaikin
label_dpchaikin64lt = $(label_dp64) ir Chaikin
legend_   = lower left
legend_tr = lower right
legend_tl = lower center

define wm_vwdp50k
RIVERS += salvis-$(1)-$(2)-$(3)-$(4)x50k$(5)
salvis-$(1)-$(2)-$(3)-$(4)x50k$(5)_1SELECT    = wm_visuals where name='salvis-$(1)'
salvis-$(1)-$(2)-$(3)-$(4)x50k$(5)_1COLOR     = orange
salvis-$(1)-$(2)-$(3)-$(4)x50k$(5)_1LABEL     = $(label_$(1))
$(if $(2),
salvis-$(1)-$(2)-$(3)-$(4)x50k$(5)_2SELECT    = wm_visuals where name='salvis-$(2)'
salvis-$(1)-$(2)-$(3)-$(4)x50k$(5)_2COLOR     = green
salvis-$(1)-$(2)-$(3)-$(4)x50k$(5)_2LABEL     = $(label_$(2))
,)
$(if $(3),
salvis-$(1)-$(2)-$(3)-$(4)x50k$(5)_3SELECT    = wm_visuals where name='salvis-$(3)'
salvis-$(1)-$(2)-$(3)-$(4)x50k$(5)_3LINESTYLE = $(6)
salvis-$(1)-$(2)-$(3)-$(4)x50k$(5)_3LABEL     = $(label_$(3))
,)
salvis-$(1)-$(2)-$(3)-$(4)x50k$(5)_WIDTHDIV   = $(4)
salvis-$(1)-$(2)-$(3)-$(4)x50k$(5)_QUADRANT   = $(5)
salvis-$(1)-$(2)-$(3)-$(4)x50k$(5)_LEGEND     = $(legend_$(5))
endef

wm_vwdp50kblack = $(call wm_vwdp50k,$(1),$(2),$(3),$(4),$(5))
wm_vwdp50kdotted = $(call wm_vwdp50k,$(1),$(2),$(3),$(4),$(5),dotted)

$(foreach x,vw64 dp64 vwchaikin64 dpchaikin64,\
	$(eval $(call wm_vwdp50kdotted,wm75,$(x),grpk10,1,)) \
)
$(eval $(call wm_vwdp50kblack,wm75,grpk50,grpk10,1))
$(eval $(call wm_vwdp50kblack,wm75,grpk50,grpk10,1,tr))
$(eval $(call wm_vwdp50kblack,wm75,grpk50,grpk10,1,tl))

$(eval $(call wm_vwdp50kblack,wm75,,grpk10,1))
$(eval $(call wm_vwdp50kblack,wm75,,grpk10,1,tr))
$(eval $(call wm_vwdp50kblack,wm75,,grpk10,1,tl))

salvis-25k_1SELECT = wm_visuals where name='salvis-grpk10'
salvis-25k_WIDTHDIV = 1

salvis-2x50k_1SELECT = wm_visuals where name='salvis-grpk10'
salvis-2x50k_WIDTHDIV = 2

salvis-dp64overlaid-2x50k_1SELECT = wm_visuals where name='salvis-grpk10'
salvis-dp64overlaid-2x50k_1LABEL = $(label_grpk10)
salvis-dp64overlaid-2x50k_2SELECT = wm_visuals where name='salvis-dp64'
salvis-dp64overlaid-2x50k_2LABEL = $(label_dp64)
salvis-dp64overlaid-2x50k_2COLOR = orange
salvis-dp64overlaid-2x50k_QUADRANT = tl
salvis-dp64overlaid-2x50k_LEGEND = $(legend_tl)

salvis-dpchaikin64overlaid-2x50k_1SELECT = wm_visuals where name='salvis-grpk10'
salvis-dpchaikin64overlaid-2x50k_1LABEL = $(label_grpk10)
salvis-dpchaikin64overlaid-2x50k_2SELECT = wm_visuals where name='salvis-dpchaikin64'
salvis-dpchaikin64overlaid-2x50k_2COLOR = orange
salvis-dpchaikin64overlaid-2x50k_2LABEL = $(label_dpchaikin64lt)
salvis-dpchaikin64overlaid-2x50k_QUADRANT = tl
salvis-dpchaikin64overlaid-2x50k_LEGEND = $(legend_tl)

salvis-dp64-2x50k_1SELECT = wm_visuals where name='salvis-dp64'
salvis-dp64-2x50k_WIDTHDIV = 2

salvis-vw64-2x50k_1SELECT = wm_visuals where name='salvis-vw64'
salvis-vw64-2x50k_WIDTHDIV = 2

salvis-dpchaikin64-2x50k_2SELECT = wm_visuals where name='salvis-dpchaikin64'
salvis-dpchaikin64-2x50k_WIDTHDIV = 2

salvis-vwchaikin64-2x50k_2SELECT = wm_visuals where name='salvis-vwchaikin64'
salvis-vwchaikin64-2x50k_WIDTHDIV = 2

salvis-overlaid-dpchaikin64-2x50k_1SELECT = wm_visuals where name='salvis-dpchaikin64'
salvis-overlaid-dpchaikin64-2x50k_2SELECT = wm_visuals where name='salvis-grpk10'
salvis-overlaid-dpchaikin64-2x50k_1COLOR = orange
salvis-overlaid-dpchaikin64-2x50k_WIDTHDIV = 2
salvis-overlaid-dpchaikin64-2x50k_QUADRANT = tl

salvis-overlaid-vwchaikin64-2x50k_1SELECT = wm_visuals where name='salvis-vwchaikin64'
salvis-overlaid-vwchaikin64-2x50k_2SELECT = wm_visuals where name='salvis-grpk10'
salvis-overlaid-vwchaikin64-2x50k_1COLOR = orange
salvis-overlaid-vwchaikin64-2x50k_WIDTHDIV = 2
salvis-overlaid-vwchaikin64-2x50k_QUADRANT = tl

salvis-wm220_1SELECT = wm_visuals where name='salvis-wm220'
salvis-wm220_WIDTHDIV = 2

define FIG_template
$(1).pdf: layer2img.py Makefile $(2)
	python3 ./layer2img.py --outfile=$(1).pdf \
		$$(if $$($(1)_LEGEND),--legend="$$($(1)_LEGEND)") \
		$$(if $$($(1)_WIDTHDIV),--widthdiv=$$($(1)_WIDTHDIV)) \
		$$(if $$($(1)_QUADRANT),--quadrant=$$($(1)_QUADRANT)) \
		$$(foreach i,1 2 3, \
			$$(if $$($(1)_$$(i)LABEL),--g$$(i)-label="$$($(1)_$$(i)LABEL)") \
			$$(if $$($(1)_$$(i)COLOR),--g$$(i)-color="$$($(1)_$$(i)COLOR)") \
			$$(if $$($(1)_$$(i)SELECT),--g$$(i)-select="$$($(1)_$$(i)SELECT)") \
			$$(if $$($(1)_$$(i)LINESTYLE),--g$$(i)-linestyle="$$($(1)_$$(i)LINESTYLE)") \
	)
endef

$(foreach fig,$(FIGURES),       $(eval $(call FIG_template,$(fig),.faux_test)))
$(foreach fig,$(FIGURES_SLIDES),$(eval $(call FIG_template,$(fig),.faux_test)))
$(foreach fig,$(RIVERS),        $(eval $(call FIG_template,$(fig),.faux_visuals)))
$(foreach fig,$(RIVERS_SLIDES), $(eval $(call FIG_template,$(fig),.faux_visuals)))

#################################
# The thesis, publishable version
#################################

mj-msc-full.pdf: mj-msc.pdf version.inc.tex $(filter-out $(SLIDES_IN),$(shell git ls-files .)) ## Thesis for publishing
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
slides: $(addsuffix .pdf,$(SLIDES))

.PHONY: refresh-rivers
refresh-rivers: refresh-rivers-10.sql refresh-rivers-50.sql refresh-rivers-250.sql ## Refresh river data from national datasets

###########################
# The report, quick version
###########################

mj-msc.pdf: mj-msc.tex version.inc.tex vars.inc.tex bib.bib \
	$(LISTINGS) $(addsuffix .pdf,$(FIGURES)) $(addsuffix .pdf,$(RIVERS))
	latexmk -shell-escape -pdf $<

###################################
# Report's DB and test dependencies
###################################

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

slides-2021-06-02.pdf: slides-2021-06-02.tex \
	amalgamate1.png \
	isolated-1-before.pdf isolated-1-after.pdf \
	salvis-dp64overlaid-2x50k.pdf \
	salvis-dpchaikin64overlaid-2x50k.pdf \
	$(wilcard *logo.pdf)
	latexmk -shell-escape -pdf $<

dump-debug_wm.sql.xz:
	docker exec -ti wm-mj pg_dump -Uosm osm -t wm_devug | xz -v > $@

mj-msc-gray.pdf: mj-msc.pdf ## Gray version, to inspect monochrome output
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
		$(addsuffix .pdf,$(SLIDES))

.PHONY: clean-tables
clean-tables: ## Remove tables created during unit or rivers tests
	bash db -c '\dt wm_*' | awk '/_/{print "drop table "$$3";"}' | bash db -f -
	-rm .faux_db

.PHONY: help
help: ## Print this help message
	@awk -F':.*?## ' '/^[a-z0-9.-]*: *.*## */{printf "%-18s %s\n",$$1,$$2}' \
		$(MAKEFILE_LIST) | sort

.PHONY: wc
wc: mj-msc.pdf
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

$(eval $(call refresh_rivers_template,rivers-10.sql,GDB10LT,wm_rivers))
$(eval $(call refresh_rivers_template,rivers-50.sql,GDR50LT,wm_rivers_50))
$(eval $(call refresh_rivers_template,rivers-250.sql,GDR250LT,wm_rivers_250))
