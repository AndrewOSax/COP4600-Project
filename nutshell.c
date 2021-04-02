#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include "global.h"
extern int yyparse();
char *getcwd(char *buf, size_t size);

void init(){
	aliasIndex = 0;
    varIndex = 0;
    char cwd[PATH_MAX];
    getcwd(cwd, sizeof(cwd));

    strcpy(varTable.var[varIndex], "PWD");
    strcpy(varTable.val[varIndex], cwd);
    varIndex++;
    strcpy(varTable.var[varIndex], "HOME");
    strcpy(varTable.val[varIndex], cwd);
    varIndex++;
    strcpy(varTable.var[varIndex], "PROMPT");
    strcpy(varTable.val[varIndex], "nutshell");
    varIndex++;
    strcpy(varTable.var[varIndex], "PATH");
    strcpy(varTable.val[varIndex], ".:/bin");
    varIndex++;

    strcpy(aliasTable.name[aliasIndex], ".");
    strcpy(aliasTable.val[aliasIndex], cwd);
    aliasIndex++;

    char *pointer = strrchr(cwd, '/');
    while(*pointer != '\0') {
        *pointer ='\0';
        pointer++;
    }
    strcpy(aliasTable.name[aliasIndex], "..");
    strcpy(aliasTable.val[aliasIndex], cwd);
    aliasIndex++;

    system("clear");
};

int main(){
	init();
	while(1){
        printf("[%s]@%s>> ", varTable.val[2], varTable.val[0]);
        yyparse();
    }
	return 0;
}