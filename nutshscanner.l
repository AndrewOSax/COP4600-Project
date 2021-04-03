%{
#include "nutshparser.tab.h"
#include <string.h>
#include <stdbool.h>
#include "global.h"

char* firstExpand(char* input){
	if (input[0] == '~'){
		char* output = varTable.val[1];
		strcat(output,++input);
		return output;
	}
	else if (input[0] == '.' && input[1] == '.'){
		char* output = aliasTable.val[1];
		strcat(output,++input);
		return output;
	}
	else if (input[0] == '.'){
		char* output = aliasTable.val[0];
		strcat(output,++input);
		return output;
	}
	else{
		return input;
	}
}
char* envExpand(char* input){
	bool scanName = false;
	char buffer[256];
	char scanned[256];
	int size = 0;
	int totalSize = 0;
	for (int i = 0; i < strlen(input); i++){
		if (!scanName && input[i] == '$' && i != strlen(input)-1 && input[i+1] == '{'){ //ENV sequence started
			char scanned[256];
			size = 0;
			i += 2;
			scanName = true;
		}
		if (scanName){
			scanned[size] = input[i];
			scanned[size+1] = '\0';
			size++;
			if (i != strlen(input)-1 && input[i+1] == '}'){ //ENV variable named, load if found
				scanName = false;
				i++;
				for (int j = 0; j < varIndex; j++) {
					if(strcmp(scanned,varTable.var[j]) == 0){
						strcat(buffer,varTable.val[j]);
						totalSize += strlen(varTable.val[j]);
					}
				}
			}
			else if(i == strlen(input)-1){ //Closing brace not found-not an ENV sequence
				strcat(buffer,"${");
				strcat(buffer,scanned);
				totalSize += strlen(scanned)+2;
			}
		}
		else{
			buffer[totalSize] = input[i];
			buffer[totalSize+1] = '\0';
			totalSize++;
		}
	}
	char* output = malloc(totalSize*sizeof(char));
	for (int i = 0; i < totalSize; i++){
		output[i] = buffer[i];
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
<expect_string>{ANYCHAR}*	{yylval.string = envExpand(strdup(yytext)); return WORD;}
<expect_string>[\"]	{ BEGIN(INITIAL);}

{DIGIT}+\.{DIGIT}+	return NUMBER_LITERAL;
{DIGIT}+ return NUMBER_LITERAL;

true|false	return BOOLEAN_LITERAL;
null	return NULL_LITERAL;

{NL}	return NEWLINE;
{META}	return META;

~ {yylval.string = strdup(varTable.val[1]); return WORD;}
"." {yylval.string = strdup(aliasTable.val[0]); return WORD;}
".." {yylval.string = strdup(aliasTable.val[1]); return WORD;}

{WHITE}+ { }
bye return BYE;
<<EOF>> {printf("\n"); return BYE;}
setenv return SETENV;
printenv return PRINTENV;
unsetenv return UNSETENV;
cd return CD;
alias return ALIAS;
unalias return UNALIAS;

{CHAR}+ {yylval.string = envExpand(strdup(yytext)); return WORD;}
%%