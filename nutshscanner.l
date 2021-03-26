%{
#include "nutshscanner.h"
#include "nutshparser.tab.h"
%}

%x expect_string

DIGIT	[0-9]
META [\[\]{},:]

QUOTE	["]
NOTQUOTE	[^"]

%%

{QUOTE}	{ BEGIN(expect_string); return META; }
<expect_string>{NOTQUOTE}*	return STRING_LITERAL;
<expect_string>{QUOTE}	{ BEGIN(INITIAL); return META; }

{DIGIT}+|{DIGIT}*\.{DIGIT}+	return NUMBER_LITERAL;
true|false	return BOOLEAN_LITERAL;
null	return NULL_LITERAL;

"\n"	return NEWLINE;
{META} return META;
