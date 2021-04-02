%{
#include "nutshparser.tab.h"
#include <string.h>
#include <stdbool.h>
#include "global.h"
%}
%array
%option noyywrap

%x expect_string

DIGIT	[0-9]
META [<>|\\&]

CHAR	[.A-Za-z0-9!\/_-]+
ANYCHAR	[)(*&%$#@!`;,\.a-zA-Z0-9'/*_=~ -]+

%%

[\"]	{ BEGIN(expect_string);}
<expect_string>{ANYCHAR}*	{yylval.string = strdup(yytext); return WORD;}
<expect_string>[\"]	{ BEGIN(INITIAL);}

{DIGIT}+\.{DIGIT}+	return NUMBER_LITERAL;
{DIGIT}+ return NUMBER_LITERAL;

true|false	return BOOLEAN_LITERAL;
null	return NULL_LITERAL;

"\n"	return NEWLINE;
{META} return META;

~ {yylval.string = strdup(varTable.val[1]); return WORD;}
"." {yylval.string = strdup(aliasTable.val[0]); return WORD;}
".." {yylval.string = strdup(aliasTable.val[1]); return WORD;}

[ \t] { }
bye return BYE;
<<EOF>> {printf("\n"); return BYE;}
setenv return SETENV;
printenv return PRINTENV;
unsetenv return UNSETENV;
cd return CD;
alias return ALIAS;
unalias return UNALIAS;

{CHAR}+ {yylval.string = strdup(yytext); return WORD;}
%%