# Simple Makefile

all:  bison-config flex-config nutshell

bison-config:
	bison -d nutshparser.y

flex-config:
	flex nutshscanner.l

nutshell: 
	gcc nutshell.c nutshparser.tab.c lex.yy.c -o nutshell.o -lfl

clean:
	rm nutshparser.tab.c nutshparser.tab.h lex.yy.c