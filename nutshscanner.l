%{
#include "nutshparser.tab.h"
#include <string>
#include "global.h"
#include <dirent.h>
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
bool wildCardMatch(std::string file,std::string pattern){ //https://www.geeksforgeeks.org/wildcard-pattern-matching/
    int n = file.size();
	int m = pattern.size();
	if (m == 0){
        return (n == 0);
	}
    bool lookup[n + 1][m + 1]; 
    memset(lookup, false, sizeof(lookup));	
    lookup[0][0] = true; 	
    for (int j = 1; j <= m; j++){
        if (pattern[j - 1] == '*'){
            lookup[0][j] = lookup[0][j - 1];
		}
	}
    for (int i = 1; i <= n; i++) {
        for (int j = 1; j <= m; j++) {
            if (pattern[j - 1] == '*'){
                lookup[i][j] = lookup[i][j - 1] || lookup[i - 1][j];
			}
            else if (pattern[j - 1] == '?' || file[i - 1] == pattern[j - 1]){
                lookup[i][j] = lookup[i - 1][j - 1];
			}
            else{
                lookup[i][j] = false;
			}
        }
    } 
    return lookup[n][m];
}
std::string wildCards(std::string input){
	bool wild = false;
	for (int i = 0; i < input.size(); i++){ 
		if (input[i] == '*' || input[i] == '?'){
			wild = true;
		}
		if (i > 0 && input[i-1] == '*' && input[i] == '*'){ //delete extra asterisks to save time
			input.erase(i,1);
			i--;
		}
	}
	if (!wild){
		return input;
	}
	std::string output = "";
	struct dirent *entry = nullptr;
    DIR *dp = nullptr;
	int oldPos = 0;
	int pos = varTable["PATH"].find(":");
	while (pos != -1){ //loop through PATH and return matches
		dp = opendir(varTable["PATH"].substr(oldPos,pos-oldPos).c_str());
		if (dp != nullptr) {
			while ((entry = readdir(dp))){
				std::string fileName = std::string(entry->d_name);
				if(wildCardMatch(fileName,input)){
					output += fileName + " ";
				}			
			}
		}
		closedir(dp);
		oldPos = pos+1;
		pos = varTable["PATH"].find(":",pos+1);	
	}
	dp = opendir(varTable["PATH"].substr(oldPos,varTable["PATH"].size()).c_str());
	if (dp != nullptr) {
		while ((entry = readdir(dp))){
			std::string fileName = std::string(entry->d_name);
			if(wildCardMatch(fileName,input)){
				output += fileName + " ";
			}		
		}
	}
	closedir(dp);
	if (output.size() == 0){ //if no matches remove wildcards and return
		for (int i = 0; i < input.size(); i++){ 
			if (input[i] != '*' && input[i] != '?'){
				output += input[i];
			}
		}
	}
	else{ //remove last space
		output = output.substr(0,output.size()-1);
	}
    return output;
}
std::string parseWords(char* text){
	std::string input = std::string(text);
	input = envExpand(input); //repalce all env fields
	if (firstWord){ //alias if first word in command
		auto iter = aliasTable.find(input);
		if (iter != aliasTable.end()){
			input = iter->second;
		}
	}
	return wildCards(input); //match wildcard characters
}
//{DIGIT}+\.{DIGIT}+	{firstWord = false; return NUMBER_LITERAL;}
//{DIGIT}+ {firstWord = false; return NUMBER_LITERAL;}
//true|false	{firstWord = false; return BOOLEAN_LITERAL;}
//null	{firstWord = false; return NULL_LITERAL;}
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

{META}	{firstWord = false; return META;}

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