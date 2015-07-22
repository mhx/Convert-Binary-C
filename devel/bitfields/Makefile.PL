#!/usr/bin/perl
use strict;

my @targets = map { /compilers\.(.*)/ }
              glob "compilers.*";

my $targets = join "\n",
              map { <<END } @targets;
$_: ${_}_dump ${_}_config ${_}_tests

${_}_dump: bitfields.c
	@\$(PERL) runcdump compilers.$_

${_}_tests: bitfields.c
	@\$(PERL) runcdump --tests compilers.$_

${_}_config:
	@\$(PERL) runccconfig compilers.$_

END

open M, ">Makefile" or die "Makefile: $!\n";
print M <<END;
PERL = $^X

RMRF = \$(PERL) -MFile::Path -e"rmtree([\@ARGV])"

TEXSTUFF = doc/bits.tex \\
           doc/bits.aux \\
           doc/bitfields.aux \\
           doc/bitfields.log

# best guess we can make
all: $^O

dump: $^O_dump

tests: $^O_tests

config: $^O_config

dist:
\t\@rm -rf bitfields
\t\@mkdir bitfields
\t\@cp b*.c compilers.* initializers Makefile.PL mkbf ccconfig cdump maketest runccconfig runcdump bitfields
\t\@tar cvzf bitfields.tar.gz bitfields
\t\@rm -rf bitfields

help:
\t\@echo Available targets: @targets

$targets

bitfields.c: bfmaster.c
\t\@\$(PERL) mkbf <bfmaster.c >bitfields.c

initializers: bitfields.c
\t\@\$(PERL) cdump --noheader --generate-initializers=5 <bitfields.c >initializers

pdf: bitfields.c
#\t\@\$(PERL) txt2tex >doc/bits.tex
#\t\@cd doc && pdflatex bitfields.tex && mv -f bitfields.pdf bitfields-compiler.pdf
\t\@\$(PERL) txt2tex -s >doc/bits.tex
\t\@cd doc && pdflatex bitfields.tex && mv -f bitfields.pdf bitfields-simple.pdf

testfiles:
\t\@\$(PERL) maketest Microsoft >../../t/502_bfmicrosoft.t
\t\@\$(PERL) maketest Generic >../../t/503_bfgeneric.t

clean:
\t\@\$(RMRF) Makefile bitfields.c \$(TEXSTUFF)

realclean: clean
\t\@\$(RMRF) doc/bitfields-compiler.pdf doc/bitfields-simple.pdf

END
close M;
