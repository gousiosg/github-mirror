# Makefile for complex Latex documents
#
# (c) 2009-2012 -- Georgios Gousios <gousiosg@gmail.com>

## Inputs
# Name of master file (without the .tex extension)
MASTERTEX=ghtorrent-data

# Where is the output dir?
BUILD=build

# Where is the latex input dir
LATEXDIR=latex

# Where should biblio.py look for papers
PAPERPATH=~/Documents/biblists

## Binaries. Can be overriden at make invocation time

# Latex parser to use
LATEX?=pdflatex

# Gnuplot 
GNUPLOT?=gnuplot

# dot (graphviz)
DOT?=dot

# epstopdf conversion
EPSTOPDF?=epstopdf

# pybcompact location
PYBCOMPACT?=pybcompact.py

PICS=figs

## Filename substitutions for genetated files

# Output file
PDFFILE=$(patsubst %.tex,%.pdf,${TEXFILE})

# Latex files in output directory
TEXFILES_SRC:=$(wildcard $(LATEXDIR)/*.tex) $(wildcard $(LATEXDIR)/*.cls) $(wildcard $(LATEXDIR)/*.bst)
TEXFILES_DEST := $(addprefix $(BUILD)/, $(notdir $(TEXFILES_SRC)))

# Bib file
BIB=$(patsubst %.tex,%,${TEXFILE})

# Latex aux file
AUXFILE=$(patsubst %.tex,%.aux,${TEXFILE})

# Files for figures, in EPS format
EPSFILES :=	$(foreach dir,$(PICS),$(wildcard $(dir)/*.eps))
EPSFILES_PDF:= $(EPSFILES:.eps=.pdf)
$(EPSFILES_PDF): $(EPSFILES)

# Gnuplot output files
PLOT_SRC_FILES := $(foreach dir,$(PICS),$(wildcard $(dir)/*.plot))
PLOT_DATA_FILES := $(foreach dir,$(PICS),$(wildcard $(dir)/*.dat))
PLOT_PDFS := $(PLOT_SRC_FILES:.plot=.pdf)
$(PLOT_PDFS) : $(PLOT_SRC_FILES) $(PLOT_DATA_FILES) 

# Files for figures, in PDF format
PDFFILES := $(foreach dir,$(PICS),$(wildcard $(dir)/*.pdf))

# Figure names in build dir
PICTURES_SRC := $(EPSFILES_PDF) $(PLOT_PDFS)
PICTURES_DEST := $(addprefix $(BUILD)/, $(notdir $(PICTURES_SRC) $(PDFFILES) $(PNGFILES))) 

# Implicit rules for various file conversions
.SUFFIXES: .eps .pdf .dat .dot

.dot.eps:
	$(DOT) -Teps -o$@ $<

.eps.pdf:
	$(EPSTOPDF) $<

%.eps: %.plot %.dat
	cd `dirname $@` && $(GNUPLOT) < `basename $<` > `basename $@`

# Default goal
.PHONY=all copy
.DEFAULT_GOAL=all

all: copy $(BUILD)/$(MASTERTEX).pdf

# Copy all files to build directory
$(BUILD):
	mkdir -p $(BUILD)

$(TEXFILES_DEST) : $(TEXFILES_SRC) $(BUILD)
	cp $(LATEXDIR)/$(@F) $@

$(PICTURES_DEST): $(PICTURES_SRC) $(BUILD)
	cp $(PICS)/$(@F) $@

copy: $(TEXFILES_DEST) $(PICTURES_DEST)

# Produce the aux file
$(BUILD)/$(MASTERTEX).aux: $(TEXFILES_DEST) $(PICTURES_DEST)
	cd $(BUILD) && \
	$(LATEX) $(MASTERTEX).tex 

# Bibliography
$(BUILD)/$(MASTERTEX).bib: $(BUILD)/$(MASTERTEX).aux
	cd $(BUILD) && \
	$(PYBCOMPACT) $(MASTERTEX).aux $(PAPERPATH) > `basename $(BUILD)/$(MASTERTEX).bib`

$(BUILD)/$(MASTERTEX).bbl: $(BUILD)/$(MASTERTEX).bib $(BUILD)/$(MASTERTEX).aux
	cd $(BUILD) && \
	bibtex $(MASTERTEX) 

# PDF
$(BUILD)/$(MASTERTEX).pdf: $(BUILD)/$(MASTERTEX).aux $(BUILD)/$(MASTERTEX).bbl
	cd $(BUILD) && \
	$(LATEX) $(MASTERTEX).tex && \
	$(LATEX) $(MASTERTEX).tex

clean:
	rm -Rf build
	-rm thesis.pdf

distclean: clean
	-rm $(PICTURES_SRC)
	-find . -type f -name .DS_Store |xargs rm
	-find . -type f |grep *~|xargs rm

