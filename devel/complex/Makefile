SHELL = /bin/bash

complex.t: Makefile header.pl begin.pl footer.pl test.1 test.2 test.4 members.1 members.2 members.4 ntypes
	@rm -f test.c
	@cat header.pl > complex.t
	@echo "use constant NALIGN => 4;" >> complex.t
	@cat ntypes >> complex.t
	@cat begin.pl >> complex.t
	@echo "%reference = (" >> complex.t
	@./test.1 >> complex.t;
	@./test.2 >> complex.t;
	@./test.4 >> complex.t;
	@echo ");" >> complex.t
	@echo "%members = (" >> complex.t
	@cat members.1 >> complex.t;
	@cat members.2 >> complex.t;
	@cat members.4 >> complex.t;
	@echo ");" >> complex.t
	@./test.1 types >> complex.t
	@./test.1 data >> complex.t
	@cat footer.pl >> complex.t
	@echo "test file made"

install: complex.t
	@cp complex.t ../../t/y_complex.t
	@echo "test file installed"

clean:
	@rm -f members.* test.* *.t ntypes

test.1: cgen.pl
	perl cgen.pl 1 > test.c && $(CC) -o test.1 test.c

test.2: cgen.pl
	perl cgen.pl 2 > test.c && $(CC) -o test.2 test.c

test.4: cgen.pl
	perl cgen.pl 4 > test.c && $(CC) -o test.4 test.c

members.1: member.pl test.1
	./test.1 member | perl member.pl 1 > members.1

members.2: member.pl test.2
	./test.2 member | perl member.pl 2 > members.2

members.4: member.pl test.4
	./test.4 member | perl member.pl 4 > members.4

ntypes: cgen.pl
	perl cgen.pl > ntypes
