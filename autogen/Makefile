SHELL = /bin/bash
PERL  = perl580mtopt

all :: clean sub
	@cd .. && make realclean

sub: module
	@cd doc && make
	@cd ppsym && make
	@cd sizes && make
	@cd complex && make

../../blib:
	@cd .. && $(PERL) Makefile.PL && make

module :: ../../blib

clean:
	@-cd .. && make realclean
