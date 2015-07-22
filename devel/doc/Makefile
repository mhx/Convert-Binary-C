SHELL = /bin/bash

CBC_PM = ../../lib/Convert/Binary/C.pm

all: install clean html

html:
	@echo "making html"
	@./convert.pl

pm:
	@echo "making documentation"
	@perl -ne'print;/^__END__/ and exit' <$(CBC_PM) >C.pm
	@./gendoc.pl <C.pod >>C.pm

clean:
	@echo "cleaning up"
	@rm -f *.html
	@rm -f C.pm

install: pm
	@echo "installing documentation"
	@cp C.pm $(CBC_PM)
