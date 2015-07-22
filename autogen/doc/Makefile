SHELL     = /bin/bash
PERL      = perl
CHECKOUT  = ../checkout.bash
CECHO     = $(PERL) -e'use Term::ANSIColor; print color(shift); print @ARGV, color("reset"), "\n"'
BLUE      = $(CECHO) "blue"

CBC_PM    = ../../lib/Convert/Binary/C.pm
CBCC_PM   = ../../lib/Convert/Binary/C/Cached.pm
CCCONFIG  = ../../bin/ccconfig

GENERATED = C.pm Cached.pm ccconfig

all :: install clean html

pdf: all
	@cd pdf && make realclean && make

../../blib:
	@cd ../.. && $(PERL) Makefile.PL && make

module :: ../../blib

pm :: $(GENERATED)

install :: ins_c ins_cached ins_ccconfig

C.pm: module
	@$(BLUE) "making C.pm"
	@$(PERL) -ne'print;/^__END__/ and exit' <$(CBC_PM) >C.pm
	@$(PERL) ./gendoc.pl <C.pod >>C.pm

Cached.pm: module
	@$(BLUE) "making Cached.pm"
	@$(PERL) -ne'print;/^__END__/ and exit' <$(CBCC_PM) >Cached.pm
	@$(PERL) ./gendoc.pl <Cached.pod >>Cached.pm

ccconfig: module
	@$(BLUE) "making ccconfig"
	@$(PERL) -ne'print;/^__END__/ and exit' <$(CCCONFIG) >ccconfig
	@$(PERL) ./gendoc.pl <ccconfig.pod >>ccconfig
	@chmod 755 ccconfig

clean:
	@$(BLUE) "cleaning up"
	@rm -f *.html
	@rm -f $(GENERATED)

ins_c : C.pm
	@if diff C.pm $(CBC_PM) >/dev/null ; then                          \
	  $(CECHO) "bold blue" "$(CBC_PM) is unchanged, skip install";     \
	else                                                               \
	  $(CHECKOUT) $(CBC_PM);                                           \
	  $(CECHO) "bold red" "installing $(CBC_PM)";                      \
	  cp C.pm $(CBC_PM);                                               \
	fi

ins_cached : Cached.pm
	@if diff Cached.pm $(CBCC_PM) >/dev/null ; then                    \
	  $(CECHO) "bold blue" "$(CBCC_PM) is unchanged, skip install";    \
	else                                                               \
	  $(CHECKOUT) $(CBCC_PM);                                          \
	  $(CECHO) "bold red" "installing $(CBCC_PM)";                     \
	  cp Cached.pm $(CBCC_PM);                                         \
	fi

ins_ccconfig : ccconfig
	@if diff ccconfig $(CCCONFIG) >/dev/null ; then                    \
	  $(CECHO) "bold blue" "$(CCCONFIG) is unchanged, skip install";   \
	else                                                               \
	  $(CHECKOUT) $(CCCONFIG);                                         \
	  $(CECHO) "bold red" "installing $(CCCONFIG)";                    \
	  cp ccconfig $(CCCONFIG);                                         \
	fi

html:
	@$(BLUE) "making html"
	@./convert.pl

diff:
	@wdiff -u $(CBC_PM)
	@wdiff -u $(CBCC_PM)
	@wdiff -u $(CCCONFIG)

ispell:
	@-wdiff $(CBC_PM) | grep '^>' >/tmp/diff
	@ispell /tmp/diff
	@rm -f /tmp/diff
	@-wdiff $(CBCC_PM) | grep '^>' >/tmp/diff
	@ispell /tmp/diff
	@rm -f /tmp/diff
	@-wdiff $(CCCONFIG) | grep '^>' >/tmp/diff
	@ispell /tmp/diff
	@rm -f /tmp/diff
