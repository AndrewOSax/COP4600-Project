# Simple Makefile

all:  bison-config flex-config nutshell

bison-config:
	bison -d nutshparser.y

flex-config:
	flex nutshscanner.l

nutshell: 
	g++ -w -o nutshell.o nutshell.cpp lex.yy.c nutshparser.tab.c 
	
clean:
	rm nutshparser.tab.c nutshparser.tab.h lex.yy.c