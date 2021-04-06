%{
#include "nutshparser.tab.h"
#include <string>
#include "global.h"
//#define unput(c) {yytchar= (c); if(yytchar=='\n') {yylineno--; *yysptr++=yytchar;}
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
std::string wildCards(std::string input){
	return input;
}
std::string parseWords(char* text){
	std::string input = std::string(text);
	input = envExpand(input);
	if (firstWord){
		auto iter = aliasTable.find(input);
		if (iter != aliasTable.end()){
			input = iter->second;
		}
	}
	return wildCards(input);
}
//{DIGIT}+\.{DIGIT}+	{firstWord = false; return NUMBER_LITERAL;}
//{DIGIT}+ {firstWord = false; return NUMBER_LITERAL;}
//true|false	{firstWord = false; return BOOLEAN_LITERAL;}
//null	{firstWord = false; return NULL_LITERAL;}
//
//{META}	{firstWord = false; return META;}
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
<expect_string>{ANYCHAR}*	{char* orig = strdup(yytext);
							 char* parsed = strdup(parseWords(orig).c_str());
							 if (strcmp(orig,parsed) != 0){
								char *yycopy = strdup(parsed);
								for ( int i = strlen(parsed) - 1; i >= 0; --i ){
									unput(yycopy[i]);
								}
								free(yycopy);
							 }
							 else{				
								firstWord = false;				
								if (strcmp(yytext,"cd") == 0 && firstWord){
									return CD;
								}
								else if(strcmp(yytext,"bye") == 0 && firstWord){
									return BYE;
								}
								else if(strcmp(yytext,"setenv") == 0 && firstWord){
									return SETENV;
								}
								else if(strcmp(yytext,"unsetenv") == 0 && firstWord){
									return UNSETENV;
								}
								else if(strcmp(yytext,"alias") == 0 && firstWord){
									return ALIAS;
								}
								else if(strcmp(yytext,"unalias") == 0 && firstWord){
									return UNALIAS;
								}
								else{
									yylval.string = strdup(yytext);
									return WORD;
								}								
							 }
							 }
<expect_string>[\"]	{ BEGIN(INITIAL);}

~ {firstWord = false; yylval.string = strdup(varTable["HOME"].c_str()); return WORD;}
"." {firstWord = false; yylval.string = strdup(aliasTable["."].c_str()); return WORD;}
".." {firstWord = false; yylval.string = strdup(aliasTable[".."].c_str()); return WORD;}
{NL}	return NEWLINE;

{WHITE}+ { }
bye {if (firstWord){firstWord = false; return BYE;} else{yylval.string = strdup(yytext); return WORD;}}
<<EOF>> {firstWord = false; printf("\n"); return BYE;}
setenv {if (firstWord){firstWord = false; return SETENV;} else{yylval.string = strdup(yytext); return WORD;}}
printenv {if (firstWord){firstWord = false; return PRINTENV;} else{yylval.string = strdup(yytext); return WORD;}}
unsetenv {if (firstWord){firstWord = false; return UNSETENV;} else{yylval.string = strdup(yytext); return WORD;}}
cd {if (firstWord){firstWord = false; return CD;} else{yylval.string = strdup(yytext); return WORD;}}
alias {if (firstWord){firstWord = false; return ALIAS;} else{yylval.string = strdup(yytext); return WORD;}}
unalias {if (firstWord){firstWord = false; return UNALIAS;} else{yylval.string = strdup(yytext); return WORD;}}

{CHAR}+ {
		 char* orig = strdup(yytext);
		 char* parsed = strdup(parseWords(orig).c_str());
		 if (strcmp(orig,parsed) != 0){
			char *yycopy = strdup(parsed);
			for ( int i = strlen(parsed) - 1; i >= 0; --i ){
				unput(yycopy[i]);
			}
			free(yycopy);
		 }
		 else{
			firstWord = false;				
			if (strcmp(yytext,"cd") == 0 && firstWord){
				return CD;
			}
			else if(strcmp(yytext,"bye") == 0 && firstWord){
				return BYE;
			}
			else if(strcmp(yytext,"setenv") == 0 && firstWord){
				return SETENV;
			}
			else if(strcmp(yytext,"unsetenv") == 0 && firstWord){
				return UNSETENV;
			}
			else if(strcmp(yytext,"alias") == 0 && firstWord){
				return ALIAS;
			}
			else if(strcmp(yytext,"unalias") == 0 && firstWord){
				return UNALIAS;
			}
			else{
				yylval.string = strdup(yytext);
				return WORD;
			}	
		 }
		 }
%%