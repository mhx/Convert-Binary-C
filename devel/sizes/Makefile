SHELL = /bin/bash

sizeof.pl: sizeof.txt mksizeof.pl
	perl mksizeof.pl <sizeof.txt >sizeof.pl
	@echo "sizeof file made"

install: sizeof.pl
	@cp sizeof.pl ../../t/include/sizeof.pl
	@echo "sizeof file installed"

clean:
	@rm -f mksizes mksizes.c *.o sizeof.pl sizeof.txt

sizeof.txt: mksizes
	./mksizes >sizeof.txt

mksizes: mksizes.c
	$(CC) -fshort-enums -I../../t/include/perlinc -I../../t/include/include -o mksizes mksizes.c

mksizes.c: mksizes.pl
	perl580 -I../../blib/lib -I../../blib/arch mksizes.pl > mksizes.c
