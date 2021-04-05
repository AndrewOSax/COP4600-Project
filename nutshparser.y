%{
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string>
#include <cstring>
#include "global.h"
int yylex();
int yyerror (char* s);
int runCD(char* dir);
int runCDhome();
int runSETENV(char* var, char* val);
int runPRINTENV();
int runUNSETENV(char* var);
int runALIASlist();
int runALIAS(char* name, char* val);
int runUNALIAS(char* name);
std::string pathExpand(char* newPath);
std::string firstExpand(std::string input);
bool aliasLoop(std::string name, std::string val);
%}

%union {char* string;}
%start cmd_line
%token <string> WORD BYE CD ALIAS SETENV PRINTENV UNSETENV UNALIAS PATH HOME NEWLINE META NUMBER_LITERAL BOOLEAN_LITERAL NULL_LITERAL
%%

cmd_line:
	BYE {exit(1); return 1;}
	| CD WORD NEWLINE {firstWord = true; runCD($2); return 1;}
	| CD NEWLINE {firstWord = true; runCDhome(); return 1;}
	| SETENV WORD WORD NEWLINE {firstWord = true; runSETENV($2,$3); return 1;}
	| PRINTENV NEWLINE {firstWord = true; runPRINTENV(); return 1;}
	| UNSETENV WORD NEWLINE {firstWord = true; runUNSETENV($2); return 1;}
	| ALIAS WORD WORD NEWLINE {firstWord = true; runALIAS($2,$3); return 1;}
	| UNALIAS WORD NEWLINE {firstWord = true; runUNALIAS($2); return 1;}
	| ALIAS NEWLINE {firstWord = true; runALIASlist(); return 1;}
	
%%

int yyerror(char *s) {
	printf("%s\n",s);
	return 0;
}

int runCDhome() {
	varTable["PWD"] = varTable["HOME"];
	aliasTable["."] = varTable["PWD"];
	int found = varTable["PWD"].rfind("/");
	if (found != -1){
		aliasTable[".."] = varTable["PWD"].substr(0,found);
	}
	else{
		aliasTable[".."] = "";
	}
	return 1;
}
int runCD(char* dir) {
	if (std::string(dir).compare("") == 0){
		return 1;
	}
	if (dir[0] != '/') { // dir is relative path
		std::string path = varTable["PWD"] + "/" + std::string(dir);
		if(chdir(path.c_str()) == 0) {
			varTable["PWD"] += "/" + std::string(dir);
			aliasTable["."] = varTable["PWD"];
			int found = varTable["PWD"].rfind("/");
			if (found != -1){
				aliasTable[".."] = varTable["PWD"].substr(0,found);
			}
			else{
				aliasTable[".."] = "";
			}
		}
		else {
			printf("Directory not found\n");
			return 1;
		}
	}
	else { // dir is absolute path
		if(chdir(dir) == 0){
			varTable["PWD"] = std::string(dir);
			aliasTable["."] = varTable["PWD"];
			int found = varTable["PWD"].rfind("/");
			if (found != -1){
				aliasTable[".."] = varTable["PWD"].substr(0,found);
			}
			else{
				aliasTable[".."] = "";
			}
		}
		else {
			printf("Directory not found\n");
            return 1;
		}
	}
	return 1;
}
std::string firstExpand(std::string input){
	if (input.size() != 0 && input[0] == '~'){
		std::string output = varTable["HOME"];
		output += input.substr(1,input.size()-1);
		return output;
	}
	else if (input.size() > 1 && input[0] == '.' && input[1] == '.'){
		std::string output = aliasTable[".."];
		output += input.substr(2,input.size()-2);
		return output;
	}
	else if (input.size() != 0 && input[0] == '.'){
		std::string output = aliasTable["."];
		output += input.substr(1,input.size()-1);
		return output;
	}
	else{
		return input;
	}
}
std::string pathExpand(char* newPath){
	std::string output = std::string(newPath);
	int oldPos = 0;
	int pos = output.find(":");
	while (pos != -1){
		int shift = output.size();
		output.replace(oldPos,pos-oldPos,firstExpand(output.substr(oldPos,pos-oldPos)));
		shift = output.size()-shift;
		oldPos = pos+1+shift;
		pos = output.find(":",pos+1+shift);	
	}
	output.replace(oldPos,output.size()-oldPos,firstExpand(output.substr(oldPos,output.size())));
	return output;
}
int runSETENV(char* var, char* val){
	if (strcmp(var, "PATH") == 0){
		varTable["PATH"] = pathExpand(val);
	}
	else{
		varTable[std::string(var)] = std::string(val);
	}	
	
	return 1;
}
int runPRINTENV(){
	for (auto i = varTable.begin(); i != varTable.end(); i++) {
		printf("%s=%s\n",i->first.c_str(),i->second.c_str());
	}
	return 1;
}
int runUNSETENV(char* var){
	if (strcmp(var,"PWD") == 0 || strcmp(var,"HOME") == 0 || strcmp(var,"PROMPT") == 0 || strcmp(var,"PATH") == 0){
		return 1;
	}
	varTable.erase(std::string(var));
	return 1;
}
int runALIASlist(){
	for (auto i = aliasTable.begin(); i != aliasTable.end(); i++) {
		printf("%s=%s\n",i->first.c_str(),i->second.c_str());
	}
	return 1;
}
bool aliasLoop(std::string name, std::string val){
/*	int start = 0;
	int end = val.find(" \t");
	while (end != -1){
		aliasTable.find(val.substr(start,end-start));
		if (find != aliasTable.end()){
			
		}
		else{
		
		}
	}*/
	return false;
}
int runALIAS(char* name, char* val){
	if(strcmp(name, val) == 0 || aliasLoop(std::string(name),std::string(val))){
		printf("Error, expansion of \"%s\" would create a loop.\n", name);
	}
	else{
		aliasTable[std::string(name)] = std::string(val);	
	}
	return 1;
}
int runUNALIAS(char* name){
	aliasTable.erase(std::string(name));
	return 1;
}