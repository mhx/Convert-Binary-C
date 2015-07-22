SHELL     = /bin/bash
PERL      = perl
CHECKOUT  = checkout_file
CECHO     = $(PERL) -e'use Term::ANSIColor; print color(shift); print @ARGV, color("reset"), "\n"'
BLUE      = $(CECHO) "blue"

GCCPATH   = /home/mhx/src/gnu/gcc
CCCONFIG  = ../../bin/ccconfig

all :: install clean

ccconfig.new: ppsym.pl $(CCCONFIG)
	@$(BLUE) "making ccconfig.new"
	@$(PERL) ppsym.pl $(GCCPATH) <$(CCCONFIG) >ccconfig.new

clean:
	@$(BLUE) "cleaning up"
	@rm -f ccconfig.new

install: ccconfig.new
	@if diff ccconfig.new $(CCCONFIG) >/dev/null ; then                \
	  $(CECHO) "bold blue" "$(CCCONFIG) is unchanged, skip install";   \
	else                                                               \
	  $(CHECKOUT) $(CCCONFIG);                                         \
	  $(CECHO) "bold red" "installing $(CCCONFIG)";                    \
	  cp ccconfig.new $(CCCONFIG);                                     \
	fi

diff: ccconfig.new
	@-diff -u $(CCCONFIG) ccconfig.new
