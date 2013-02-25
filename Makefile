ifeq ($(shell which convert 2>/dev/null),)
CONVERT = echo
else
CONVERT = convert
endif

FIG_PDFS = data_flow.pdf kmers.pdf layers.pdf

all: main.tex $(FIG_PDFS)
	pdflatex main.tex
	bibtex main.aux
	pdflatex main.tex
	pdflatex main.tex

#e.g. use git show c1275:assembly-paper.tex > OLD-assembly-paper.tex
diff:
	latexdiff-so OLD-main.tex main.tex > DIFF-main.tex
	pdflatex DIFF-main.tex
	bibtex DIFF-main.aux
	pdflatex DIFF-main.tex
	pdflatex DIFF-main.tex

clean:
	-rm -f *.aux *.log *.bbl *.blg *.dvi *.pdf 

%.pdf: %.eps
	$(CONVERT) $< $@

# vim: set ft=make tw=79:
