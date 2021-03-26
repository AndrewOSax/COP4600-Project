%{
#include <stdio.h>
int yylex();
void yyerror (char const *s);
%}

%token KEYWORD_WHILE
%token LPAREN RPAREN LCURLY RCURLY
%token OP_EQUALITY
%token NUM
%token SEMI

%%

stmt:
	while ;
expr:
	NUM ;

while: KEYWORD_WHILE LPAREN expr RPAREN block ;

block: LCURLY s_list RCURLY ;

s_list: %empty | s_list stmt SEMI ;

%%

void yyerror (char const *s) {
   fprintf(stderr, "%s\n", s);
}