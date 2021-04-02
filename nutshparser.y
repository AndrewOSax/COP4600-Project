%{
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include "global.h"
#include <stdbool.h>
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
%}

%union {char* string;}
%start cmd_line
%token <string> WORD BYE CD ALIAS SETENV PRINTENV UNSETENV UNALIAS PATH HOME NEWLINE META NUMBER_LITERAL BOOLEAN_LITERAL NULL_LITERAL
%%

cmd_line:
	BYE {exit(1); return 1;}
	| CD WORD NEWLINE {runCD($2); return 1;}
	| CD NEWLINE {runCDhome(); return 1;}
	| SETENV WORD WORD NEWLINE {runSETENV($2,$3); return 1;}
	| PRINTENV NEWLINE {runPRINTENV(); return 1;}
	| UNSETENV WORD NEWLINE {runUNSETENV($2); return 1;}
	| ALIAS WORD WORD NEWLINE {runALIAS($2,$3); return 1;}
	| UNALIAS WORD NEWLINE {runUNALIAS($2); return 1;}
	| ALIAS NEWLINE {runALIASlist(); return 1;}
	
%%

int yyerror(char *s) {
	printf("%s\n",s);
	return 0;
}

int runCDhome() {
	char* dir = varTable.val[1];
	strcpy(aliasTable.val[0], dir);
	strcpy(aliasTable.val[1], dir);
	strcpy(varTable.val[0], dir);
	char *pointer = strrchr(aliasTable.val[1], '/');
	while(*pointer != '\0') {
		*pointer ='\0';
		pointer++;
	}
	return 1;
}
int runCD(char* dir) {
	if (dir[0] != '/') { // dir is relative path
		strcat(varTable.val[0], "/");
		strcat(varTable.val[0], dir);

		if(chdir(varTable.val[0]) == 0) {
			strcpy(aliasTable.val[0], varTable.val[0]);
			strcpy(aliasTable.val[1], varTable.val[0]);
			char *pointer = strrchr(aliasTable.val[1], '/');
			while(*pointer != '\0') {
				*pointer ='\0';
				pointer++;
			}
		}
		else {
			char *pointer = strrchr(varTable.val[0], '/');
			while(*pointer != '\0') {
				*pointer ='\0';
				pointer++;
			}
			printf("Directory not found\n");
			return 1;
		}
	}
	else { // dir is absolute path
		if(chdir(dir) == 0){
			strcpy(aliasTable.val[0], dir);
			strcpy(aliasTable.val[1], dir);
			strcpy(varTable.val[0], dir);
			char *pointer = strrchr(aliasTable.val[1], '/');
			while(*pointer != '\0') {
				*pointer ='\0';
				pointer++;
			}
		}
		else {
			printf("Directory not found\n");
                       	return 1;
		}
	}
	return 1;
}
int runSETENV(char* var, char* val){
	strcpy(varTable.var[varIndex], var);
	strcpy(varTable.val[varIndex], val);
	varIndex++;
	
	return 1;
}
int runPRINTENV(){
	for (int i = 0; i < varIndex; i++) {
		printf("%s=%s\n",varTable.var[i],varTable.val[i]);
	}
	return 1;
}
int runUNSETENV(char* var){
	if (strcmp(var,"PWD") == 0 || strcmp(var,"HOME") == 0 || strcmp(var,"PROMPT") == 0 || strcmp(var,"PATH") == 0){
		return 1;
	}
	bool found = false;
	for (int i = 0; i < varIndex; i++) {
		if (found){
			strcpy(varTable.var[i-1],varTable.var[i]);
			strcpy(varTable.val[i-1],varTable.val[i]);
		}
		if (strcmp(varTable.var[i],var) == 0){
			found = true;
		}		
	}
	if (found){
		varIndex--;
	}
	return 1;
}
int runALIASlist(){
	for (int i = 0; i < aliasIndex; i++) {
		printf("%s=%s\n",aliasTable.name[i],aliasTable.val[i]);
	}
	return 1;
}
int runALIAS(char* name, char* val){
	for (int i = 0; i < aliasIndex; i++) {
		if(strcmp(name, val) == 0){
			printf("Error, expansion of \"%s\" would create a loop.\n", name);
			return 1;
		}
		else if((strcmp(aliasTable.name[i], name) == 0) && (strcmp(aliasTable.val[i], val) == 0)){
			printf("Error, expansion of \"%s\" would create a loop.\n", name);
			return 1;
		}
		else if(strcmp(aliasTable.name[i], name) == 0) {
			strcpy(aliasTable.val[i], val);
			return 1;
		}
	}
	strcpy(aliasTable.name[aliasIndex], name);
	strcpy(aliasTable.val[aliasIndex], val);
	aliasIndex++;
	
	return 1;
}
int runUNALIAS(char* name){
	bool found = false;
	for (int i = 0; i < aliasIndex; i++) {
		if (found){
			strcpy(aliasTable.name[i-1],aliasTable.name[i]);
			strcpy(aliasTable.val[i-1],aliasTable.val[i]);
		}
		if (strcmp(aliasTable.name[i],name) == 0){
			found = true;
		}		
	}
	if (found){
		aliasIndex--;
	}
	return 1;
}