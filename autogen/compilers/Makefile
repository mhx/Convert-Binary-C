SHELL     = /bin/bash
PERL      = perl
CHECKOUT  = checkout_file
CECHO     = $(PERL) -e'use Term::ANSIColor; print color(shift); print @ARGV, color("reset"), "\n"'
BLUE      = $(CECHO) "blue"

CC        = gcc

all :: test.h

../../blib:
	@cd ../.. && $(PERL) Makefile.PL && make

module :: ../../blib

test.h: Makefile module cgen.pl
	@$(BLUE) "making test.h"
	@$(PERL) cgen.pl >test.h

# install: test.h
# 	@if diff complex.t $(COMPLEX) >/dev/null ; then                 \
# 	  $(CECHO) "bold blue" "$(COMPLEX) is unchanged, skip install"; \
# 	else                                                            \
# 	  $(CHECKOUT) $(COMPLEX);                                       \
# 	  $(CECHO) "bold red" "installing $(COMPLEX)";                  \
# 	  cp complex.t $(COMPLEX);                                      \
# 	fi

clean:
	@$(BLUE) "cleaning up"
	@rm -f test.h

# test: module complex.t
# 	$(PERL) -I../../blib/lib -I../../blib/arch -c complex.t
# 
# runtest: module complex.t
# 	$(PERL) -I../../blib/lib -I../../blib/arch complex.t
# 
# harness: module complex.t
# 	PERL_DL_NONLAZY=1 `which $(PERL)` \
# 	"-MExtUtils::Command::MM" "-e" "test_harness(0, '../../blib/lib', '../../blib/arch')" complex.t
