SHELL     = /bin/bash
PERL      = perl
CHECKOUT  = checkout_file
CECHO     = $(PERL) -e'use Term::ANSIColor; print color(shift); print @ARGV, color("reset"), "\n"'
BLUE      = $(CECHO) "blue"

CC        = gcc

COMPLEX   = ../../tests/603_complex.t

all :: test harness install clean

../../blib:
	@cd ../.. && $(PERL) Makefile.PL && make

module :: ../../blib

complex.t: Makefile wrap.pl header.pl begin.pl footer.pl test.1 test.2 test.4 members.1 members.2 members.4 sizeofs.1 sizeofs.2 sizeofs.4 ntypes
	@$(BLUE) "making complex.t"
	@$(PERL) -ne'/^#/ or exit; print' <$(COMPLEX) > complex.t
	@cat header.pl >> complex.t
	@echo "use constant NALIGN => 4;" >> complex.t
	@cat ntypes >> complex.t
	@cat begin.pl >> complex.t
	@echo "my %reference = (" >> complex.t
	@./test.1 | $(PERL) wrap.pl >> complex.t;
	@./test.2 | $(PERL) wrap.pl >> complex.t;
	@./test.4 | $(PERL) wrap.pl >> complex.t;
	@echo ");" >> complex.t
	@echo "my %members = (" >> complex.t
	@cat members.1 >> complex.t;
	@cat members.2 >> complex.t;
	@cat members.4 >> complex.t;
	@echo ");" >> complex.t
	@echo "my %sizeofs = (" >> complex.t
	@cat sizeofs.1 >> complex.t;
	@cat sizeofs.2 >> complex.t;
	@cat sizeofs.4 >> complex.t;
	@echo ");" >> complex.t
	@./test.1 types >> complex.t
	@./test.1 data >> complex.t
	@cat footer.pl >> complex.t

install: complex.t
	@if diff complex.t $(COMPLEX) >/dev/null ; then                 \
	  $(CECHO) "bold blue" "$(COMPLEX) is unchanged, skip install"; \
	else                                                            \
	  $(CHECKOUT) $(COMPLEX);                                       \
	  $(CECHO) "bold red" "installing $(COMPLEX)";                  \
	  cp complex.t $(COMPLEX);                                      \
	fi

clean:
	@$(BLUE) "cleaning up"
	@rm -f members.* sizeofs.* test.* *.t ntypes _sub_*.c

test: module complex.t
	$(PERL) -I../../blib/lib -I../../blib/arch -c complex.t

runtest: module complex.t
	$(PERL) -I../../blib/lib -I../../blib/arch complex.t

harness: module complex.t
	PERL_DL_NONLAZY=1 `which $(PERL)` \
	"-MExtUtils::Command::MM" "-e" "test_harness(0, '../../blib/lib', '../../blib/arch')" complex.t

test.1: cgen.pl
	@rm -f test.c _sub_*.c
	$(PERL) cgen.pl 1
	@grep '^typedef' test.h
	$(CC) -O0 -o test.1 test.c _sub_*.c

test.2: cgen.pl
	@rm -f test.c _sub_*.c
	$(PERL) cgen.pl 2
	@grep '^typedef' test.h
	$(CC) -O0 -o test.2 test.c _sub_*.c

test.4: cgen.pl
	@rm -f test.c _sub_*.c
	$(PERL) cgen.pl 4
	@grep '^typedef' test.h
	$(CC) -O0 -o test.4 test.c _sub_*.c

members.1: member.pl test.1
	./test.1 member | $(PERL) member.pl 1 > members.1

members.2: member.pl test.2
	./test.2 member | $(PERL) member.pl 2 > members.2

members.4: member.pl test.4
	./test.4 member | $(PERL) member.pl 4 > members.4

sizeofs.1: sizeof.pl test.1
	./test.1 member | $(PERL) sizeof.pl 1 > sizeofs.1

sizeofs.2: sizeof.pl test.2
	./test.2 member | $(PERL) sizeof.pl 2 > sizeofs.2

sizeofs.4: sizeof.pl test.4
	./test.4 member | $(PERL) sizeof.pl 4 > sizeofs.4

ntypes: cgen.pl
	$(PERL) cgen.pl > ntypes
