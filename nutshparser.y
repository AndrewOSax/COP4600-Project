%{
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string>
#include <cstring>
#include "global.h"
#include <dirent.h>
#include <vector>
#include <sys/wait.h>
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
std::string firstExpand(std::string input, bool pathParsing);
int executeCommand(std::vector<std::string> &command);
int runOtherCommand();
void clearOtherCommand();
std::vector<std::string> commandList;
std::vector<std::string> pipeCommandList;
std::vector<std::vector<std::string>> pipeList;
std::string stdinFile;
std::string stdoutFile;
bool stdoutAppend;
std::string stderrFile;
bool background;
%}

%union {char* string;}
%start cmd_line
%token <string> WORD BYE CD ALIAS SETENV PRINTENV UNSETENV UNALIAS NEWLINE META BASIC_PIPE PIPE_IN PIPE_OUT PIPE_OUT_OUT PIPE_ERR PIPE_ERR_OUT AND
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
	| other {firstWord = true; return 1;}
	;

other:
	command pipes pipein pipeout pipeerr wait {runOtherCommand(); clearOtherCommand();}
	;
command:
	WORD args {commandList.insert(commandList.begin(),std::string($1));}
	;
args:
	%empty
	| args WORD {commandList.push_back(std::string($2));}
	;
pipes:
	%empty
	| pipes BASIC_PIPE command_pipe {pipeList.push_back(pipeCommandList);pipeCommandList.clear();}
	;
command_pipe:
	WORD args_pipe {pipeCommandList.insert(pipeCommandList.begin(),std::string($1));}
	;
args_pipe:
	%empty
	| args_pipe WORD {pipeCommandList.push_back(std::string($2));}
	;
pipein:
	%empty
	| PIPE_IN WORD {stdinFile = std::string($2);}
	;
pipeout:
	%empty
	| PIPE_OUT WORD {stdoutFile = std::string($2); stdoutAppend = false;}
	| PIPE_OUT_OUT WORD {stdoutFile = std::string($2); stdoutAppend = true;}
	;
pipeerr:
	%empty
	| PIPE_ERR WORD {stderrFile = std::string($2);}
	| PIPE_ERR_OUT {stderrFile = "STDOUT";}
	;
wait:
	%empty
	| AND {background = true;}
	;
%%
void clearOtherCommand(){
	commandList.clear();
	pipeCommandList.clear();
	pipeList.clear();
	stdinFile.clear();
	stdoutFile.clear();
	stderrFile.clear();
	stdoutAppend = false;
	background = false;
}
int yyerror(char *s){
	printf("%s\n",s);
	return 0;
}

int runCDhome(){ //cd with no args passed
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
int runCD(char* dir){
	std::string dirExpand = firstExpand(std::string(dir),false);
	if (dirExpand.compare("") == 0){
		return 1;
	}
	if (dirExpand[0] != '/') { // dir is relative path
		std::string path = varTable["PWD"] + "/" + dirExpand;
		if(chdir(path.c_str()) == 0) {
			varTable["PWD"] += "/" + dirExpand;
			aliasTable["."] = varTable["PWD"];
			int found = varTable["PWD"].rfind("/");
			if (found != -1){
				aliasTable[".."] = varTable["PWD"].substr(0,found);
			}
			else{
				aliasTable[".."] = "";
			}
		}
		else{
			printf("Directory not found\n");
			return 1;
		}
	}
	else { // dir is absolute path
		if(chdir(dirExpand.c_str()) == 0){
			varTable["PWD"] = dirExpand;
			aliasTable["."] = varTable["PWD"];
			int found = varTable["PWD"].rfind("/");
			if (found != -1){
				aliasTable[".."] = varTable["PWD"].substr(0,found);
			}
			else{
				aliasTable[".."] = "";
			}
		}
		else{
			printf("Directory not found\n");
            return 1;
		}
	}
	return 1;
}
std::string firstExpand(std::string input,bool pathParsing){ //Tilde, dot, and dotdot expansion
	if (input.size() != 0 && input[0] == '~'){
		std::string output = varTable["HOME"];
		output += input.substr(1,input.size()-1);
		return output;
	}
	else if (!pathParsing && input.size() > 1 && input[0] == '.' && input[1] == '.'){
		std::string output = aliasTable[".."];
		output += input.substr(2,input.size()-2);
		return output;
	}
	else if (!pathParsing && input.size() != 0 && input[0] == '.'){
		std::string output = aliasTable["."];
		output += input.substr(1,input.size()-1);
		return output;
	}
	else{
		return input;
	}
}
std::string pathExpand(char* newPath){ //Tilde expand PATH variable
	std::string output = std::string(newPath);
	int oldPos = 0;
	int pos = output.find(":");
	bool dotFound = false;
	while (pos != -1){
		int shift = output.size();
		if (output.substr(oldPos,pos-oldPos).compare(".") == 0 || output.substr(oldPos,pos-oldPos).compare(aliasTable["."]) == 0){
			dotFound = true;
		}
		output.replace(oldPos,pos-oldPos,firstExpand(output.substr(oldPos,pos-oldPos),true));
		shift = output.size()-shift;
		oldPos = pos+1+shift;
		pos = output.find(":",pos+1+shift);	
	}
	output.replace(oldPos,output.size()-oldPos,firstExpand(output.substr(oldPos,output.size()),true));
	if (!dotFound){ //Add home if not present
		output += ":.";
	}
	return output;
}
int runSETENV(char* var, char* val){
	if (strcmp(var, "PATH") == 0){ //PATH is special
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
int runALIAS(char* name, char* val){
	std::string names = std::string(name);
	std::string vals = std::string(val);
	int end = vals.find_first_of(" \t");
	if (end == -1){
		end = vals.size();
	}
	if(names.compare(vals.substr(0,end)) == 0){
		printf("Error, expansion of \"%s\" would create a loop.\n", name);
	}
	else{
		auto iter = aliasTable.find(vals.substr(0,end));
		if (iter != aliasTable.end()){
			std::string alias = iter->second;
			int enda = alias.find_first_of(" \t");
			if (enda == -1){
				enda = alias.size();
			}
			if(names.compare(alias.substr(0,enda)) == 0){
				printf("Error, expansion of \"%s\" would create a loop.\n", name);
				return 1;
			}
			else{
				vals.replace(0,end,alias);
			}			
		}
		aliasTable[names] = vals;	
	}
	return 1;
}
int runUNALIAS(char* name){
	aliasTable.erase(std::string(name));
	return 1;
}
int executeCommand(std::vector<std::string> &command){
	if (command[0][0] != '/') { // cmd is relative path
		struct dirent *entry = nullptr;
		DIR *dp = nullptr;
		int oldPos = 0;
		int pos = varTable["PATH"].find(":");
		while (pos != -1){ //loop through PATH and return matches
			dp = opendir(varTable["PATH"].substr(oldPos,pos-oldPos).c_str());
			if (dp != nullptr) {
				while ((entry = readdir(dp))){
					std::string fileName = std::string(entry->d_name);
					if(fileName.compare(command[0]) == 0){
						int status;
						char* args[command.size()+1];
						args[0] = strdup((varTable["PATH"].substr(oldPos,pos-oldPos)+"/"+fileName).c_str());
						for (int i = 1; i < command.size(); i++){
							args[i] = strdup(command[i].c_str());
						}
						args[command.size()] = NULL;
						pid_t p = fork();
						if (p < 0){
							fprintf(stderr, "fork Failed" );
							return 1;
						}
						else if (p == 0){
							execv(args[0],args);
							exit(0);
						}
						else{
							wait(&status);
						}
						return 1;
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
				if(fileName.compare(command[0]) == 0){
					int status;
					char* args[command.size()+1];
					args[0] = strdup((varTable["PATH"].substr(oldPos,varTable["PATH"].size())+"/"+fileName).c_str());
					for (int i = 1; i < command.size(); i++){
						args[i] = strdup(command[i].c_str());
					}
					args[command.size()] = NULL;
					pid_t p = fork();
					if (p < 0){
						fprintf(stderr, "fork Failed" );
						return 0;
					}
					else if (p == 0){
						execv(args[0],args);
						exit(0);
					}
					else{
						wait(&status);
					}
					return 1;
				}
			}
		}
		closedir(dp);
		printf("Error: command \"%s\" not found\n",command[0].c_str());
	}
	else{
		int pos = command[0].rfind("/");
		struct dirent *entry = nullptr;
		DIR *dp = nullptr;
		dp = opendir(command[0].substr(0,pos).c_str());
		if (dp != nullptr) {
			while ((entry = readdir(dp))){
				std::string fileName = std::string(entry->d_name);
				if(fileName.compare(command[0].substr(pos+1,command[0].size())) == 0){
					int status;
					char* args[command.size()+1];
					for (int i = 0; i < command.size(); i++){
						args[i] = strdup(command[i].c_str());
					}
					args[command.size()] = NULL;
					pid_t p = fork();
					if (p < 0){
						fprintf(stderr, "fork Failed" );
						return 0;
					}
					else if (p == 0){
						execv(args[0],args);
						exit(0);
					}
					else{
						wait(&status);
					}
					return 1;
				}
			}
		}
		printf("Error: command \"%s\" not found\n",command[0].c_str());
	}
	return 0;
}
int runOtherCommand(){
	executeCommand(commandList);
	for (int i = 0; i < pipeList.size(); i++){
		executeCommand(pipeList[i]);
	}
}