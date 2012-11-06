ifeq ($(shell which convert),)
CONVERT = echo
else
CONVERT = convert
endif

FIG_PDFS = data_flow.pdf kmers.pdf layers.pdf

all: $(FIG_PDFS)
	pdflatex main.tex
	bibtex main.aux
	pdflatex main.tex
	pdflatex main.tex

clean:
	-rm -f *.aux *.log *.bbl *.blg *.dvi *.pdf 

%.pdf: %.eps
	$(CONVERT) $< $@

# vim: set ft=make tw=79:
