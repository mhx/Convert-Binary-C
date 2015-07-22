SHELL     = /bin/bash
PERL      = perl
CHECKOUT  = checkout_file
CECHO     = $(PERL) -e'use Term::ANSIColor; print color(shift); print @ARGV, color("reset"), "\n"'
BLUE      = $(CECHO) "blue"

P2L       = pod2latex
P2LOPTS   = -verbose -modify

TEX       = pdflatex
MAKEINDEX = makeindex
VERSION   = `perl -e'print q($$Snapshot:-->/Convert-Binary-C/0.69<!--$$)=~/([\w.]+)[^\/]+$$/'`

CBC_PM    = ../../../lib/Convert/Binary/C.pm
CBCC_PM   = ../../../lib/Convert/Binary/C/Cached.pm
CCCONFIG  = ../../../bin/ccconfig
POD       = $(CBC_PM) $(CBCC_PM) $(CCCONFIG)

LETTER    = CBC-$(VERSION)-Letter.pdf
A4        = CBC-$(VERSION)-A4.pdf

all: letter a4

clean:
	@rm -f main.tex cbc-*.tex cbc-*.aux cbc-*.log cbc-*.out cbc-*.toc cbc-*.idx cbc-*.ilg cbc-*.ind cbc-*.cb

realclean: clean
	@rm -f *.pdf

cbc-a4.tex: mktemplate
	@./mktemplate a4 $(VERSION) >$@

cbc-letter.tex: mktemplate
	@./mktemplate letter $(VERSION) >$@

main.tex: $(POD) Makefile convert Pod/MyLaTeX.pm
	@./convert main.tex $(POD)

a4: Makefile cbc-a4.tex main.tex cbc.ist cbc.sty
	@$(TEX) cbc-a4.tex
	@$(MAKEINDEX) -s cbc.ist cbc-a4.idx
	@$(TEX) cbc-a4.tex
	@$(TEX) cbc-a4.tex
	@mv cbc-a4.pdf $(A4)

letter: Makefile cbc-letter.tex main.tex cbc.ist cbc.sty
	@$(TEX) cbc-letter.tex
	@$(MAKEINDEX) -s cbc.ist cbc-letter.idx
	@$(TEX) cbc-letter.tex
	@$(TEX) cbc-letter.tex
	@mv cbc-letter.pdf $(LETTER)

