ifeq ($(shell which convert 2>/dev/null),)
CONVERT = echo
else
CONVERT = convert
endif

FIG_PDFS = data_flow.pdf kmers.pdf layers.pdf

all: main.pdf

main.pdf: main.tex $(FIG_PDFS)
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

arxiv.tar.gz: main.pdf
	rm -fr ./arxiv/
	mkdir arxiv
	cp main.tex ./arxiv/
	cp bloomFilter.pdf data_flow.pdf kmers.pdf layers.pdf scaling.pdf ./arxiv/
	cp main.bbl ./arxiv/
	@rm -f arxiv.tar.gz
	cd arxiv && tar czf ../arxiv.tar.gz *

%.pdf: %.eps
	$(CONVERT) $< $@

# vim: set ft=make tw=79:
