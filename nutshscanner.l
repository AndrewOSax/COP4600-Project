%{
#include "nutshparser.tab.h"
#include <string>
#include "global.h"

std::string envExpand(std::string input){
	bool scanName = false;
	std::string output = "";
	std::string scanned = "";
	for (int i = 0; i < input.size(); i++){
		if (!scanName && input[i] == '$' && i != input.size()-1 && input[i+1] == '{'){ //ENV sequence started
			scanned = "";
			i += 2;
			scanName = true;
		}
		if (scanName){
			scanned += input[i];
			if (i != input.size()-1 && input[i+1] == '}'){ //ENV variable named, load if found
				scanName = false;
				i++;
				for (auto j = varTable.begin(); j != varTable.end(); j++) {
					if(scanned.compare(j->first) == 0){
						output += j->second;
					}
				}
			}
			else if(i == input.size()-1){ //Closing brace not found-not an ENV sequence
				output += "${";
				output += "scanned";
			}
		}
		else{
			output += input[i];
		}
	}
	return output;
}
%}
%array
%option noyywrap

%x expect_string

DIGIT	[0-9]
META [<>|\\&]

WHITE [ \t]
NL "\n"

ANYCHAR [^\"]
CHAR [^ \t\n<>|\\&"]
%%

[\"]	{ BEGIN(expect_string);}
<expect_string>{ANYCHAR}*	{yylval.string = strdup(envExpand(std::string(yytext)).c_str()); return WORD;}
<expect_string>[\"]	{ BEGIN(INITIAL);}

{DIGIT}+\.{DIGIT}+	return NUMBER_LITERAL;
{DIGIT}+ return NUMBER_LITERAL;

true|false	return BOOLEAN_LITERAL;
null	return NULL_LITERAL;

{NL}	return NEWLINE;
{META}	return META;

~ {yylval.string = strdup(varTable["HOME"].c_str()); return WORD;}
"." {yylval.string = strdup(aliasTable["."].c_str()); return WORD;}
".." {yylval.string = strdup(aliasTable[".."].c_str()); return WORD;}

{WHITE}+ { }
bye return BYE;
<<EOF>> {printf("\n"); return BYE;}
setenv return SETENV;
printenv return PRINTENV;
unsetenv return UNSETENV;
cd return CD;
alias return ALIAS;
unalias return UNALIAS;

{CHAR}+ {yylval.string = strdup(envExpand(std::string(yytext)).c_str()); return WORD;}
%%