#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <unistd.h>
#include <limits.h>
#include "global.h"
#include <unordered_map>
extern int yyparse();
char *getcwd(char *buf, size_t size);
std::unordered_map<std::string,std::string> varTable;
std::unordered_map<std::string,std::string> aliasTable;
bool firstWord;

void init(){
    char cwd[PATH_MAX];
    getcwd(cwd, sizeof(cwd));
	std::string pwd = std::string(cwd);
	varTable.emplace("PWD",pwd);
	varTable.emplace("HOME",pwd);
    varTable.emplace("PROMPT","nutshell");
	varTable.emplace("PATH",".:/bin");

	aliasTable.emplace(".",pwd);
	int found = pwd.rfind("/");
	if (found != -1){
		aliasTable.emplace("..",pwd.substr(0,found));
	}
	else{
		aliasTable.emplace("..","");
	}
	
	firstWord = true;
};

int main(int argc, char** argv){
	init();
	while(true){
		if (isatty(STDIN_FILENO)){
			fprintf(stdout,"\033[0;32m[%s]\033[0m@\033[0;35m%s\033[0m>> ", varTable["PROMPT"].c_str(), varTable["PWD"].c_str());
		}
        yyparse();
    }
	return 0;
}