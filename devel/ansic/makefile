CFLAGS = -O
LEX = flex -f
# LEX = lex
YACC = yacc -vd

OBJS =  lex.yy.o \
	y.tab.o \
	main.o \
	hash.o \
	emalloc.o \
	name-space.o

parse-backend: $(OBJS)
	$(CC) -g $(OBJS) -o parse-backend

y.tab.o: y.tab.c y.tab.h

y.tab.c y.tab.h: gram.y
	$(YACC) gram.y

lex.yy.o: lex.yy.c y.tab.h

lex.yy.c: scan.l
	$(LEX) scan.l
