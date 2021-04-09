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
int runCD(std::string dir);
int runSETENV(std::string var, std::string val);
int runPRINTENV();
int runUNSETENV(std::string var);
int listAlias();
int runALIAS(std::string name, std::string val);
int runUNALIAS(std::string name);
std::string pathExpand(std::string newPath);
std::string firstExpand(std::string input, bool pathParsing);
int executeCommand(std::vector<std::string> &command);
int runCommand();
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
%token <string> WORD NEWLINE META BASIC_PIPE PIPE_IN PIPE_OUT PIPE_OUT_OUT PIPE_ERR PIPE_ERR_OUT AND
%%

cmd_line:
	command pipes pipein pipeout pipeerr wait NEWLINE {firstWord = true; runCommand(); clearOtherCommand(); return 1;}
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

int runCD(std::string dir){
	dir = firstExpand(dir,false);
	if (dir.compare("") == 0){
		return 1;
	}
	if (dir[0] != '/') { // dir is relative path
		std::string path = varTable["PWD"] + "/" + dir;
		if(chdir(path.c_str()) == 0) {
			varTable["PWD"] += "/" + dir;
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
		if(chdir(dir.c_str()) == 0){
			varTable["PWD"] = dir;
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
std::string pathExpand(std::string newPath){ //Tilde expand PATH variable
	int oldPos = 0;
	int pos = newPath.find(":");
	bool dotFound = false;
	while (pos != -1){
		int shift = newPath.size();
		if (newPath.substr(oldPos,pos-oldPos).compare(".") == 0 || newPath.substr(oldPos,pos-oldPos).compare(aliasTable["."]) == 0){
			dotFound = true;
		}
		newPath.replace(oldPos,pos-oldPos,firstExpand(newPath.substr(oldPos,pos-oldPos),true));
		shift = newPath.size()-shift;
		oldPos = pos+1+shift;
		pos = newPath.find(":",pos+1+shift);	
	}
	newPath.replace(oldPos,newPath.size()-oldPos,firstExpand(newPath.substr(oldPos,newPath.size()),true));
	if (!dotFound){ //Add home if not present
		newPath += ":.";
	}
	return newPath;
}
int runSETENV(std::string var, std::string val){
	if (var.compare("PATH") == 0){ //PATH is special
		varTable["PATH"] = pathExpand(val);
	}
	else{
		varTable[var] = val;
	}
	return 1;
}
int runPRINTENV(){
	for (auto i = varTable.begin(); i != varTable.end(); i++) {
		printf("%s=%s\n",i->first.c_str(),i->second.c_str());
	}
	return 1;
}
int runUNSETENV(std::string var){
	if (var.compare("PWD") == 0 || var.compare("HOME") == 0 || var.compare("PROMPT") == 0 || var.compare("PATH") == 0){
		return 1;
	}
	varTable.erase(var);
	return 1;
}
int listAlias(){
	for (auto i = aliasTable.begin(); i != aliasTable.end(); i++) {
		printf("%s=%s\n",i->first.c_str(),i->second.c_str());
	}
	return 1;
}
int runALIAS(std::string name, std::string val){
	if(name.compare(val) == 0){
		printf("Error, expansion of \"%s\" would create a loop.\n", name.c_str());
	}
	else{
		auto iter = aliasTable.find(val);
		while (iter != aliasTable.end()){
			std::string alias = iter->second;
			if(name.compare(alias) == 0){
				printf("Error, expansion of \"%s\" would create a loop.\n", name.c_str());
				return 1;
			}
			iter = aliasTable.find(alias);
		}
		aliasTable[name] = val;	
	}
	return 1;
}
int runUNALIAS(std::string name){
	aliasTable.erase(name);
	return 1;
}
int executeCommand(std::vector<std::string> &command){
	if (command[0].compare("bye") == 0){
		printf("Goodbye\n");
		exit(1);
		return 1;
	}
	else if (command[0].compare("cd") == 0){
		if (command.size() == 1){
			runCD(varTable["HOME"]);
		}
		else if (command.size() == 2){
			runCD(command[1]);
		}
		else{
			printf("Error, incorrect number of arguments for cd.\n");
		}		
		return 1;
	}
	else if (command[0].compare("setenv") == 0){
		if (command.size() == 3){
			runSETENV(command[1],command[2]);
		}
		else{
			printf("Error, incorrect number of arguments for setenv.\n");
		}		
		return 1;
	}
	else if (command[0].compare("printenv") == 0){
		if (command.size() == 1){
			runPRINTENV();
		}
		else{
			printf("Error, incorrect number of arguments for printenv.\n");
		}
		return 1;
	}
	else if (command[0].compare("unsetenv") == 0){
		if (command.size() == 2){
			runUNSETENV(command[1]);
		}
		else{
			printf("Error, incorrect number of arguments for unsetenv.\n");
		}
		return 1;
	}
	else if (command[0].compare("alias") == 0){
		if (command.size() == 1){
			listAlias();
		}
		else if (command.size() == 3){
			runALIAS(command[1],command[2]);
		}
		else{
			printf("Error, incorrect number of arguments for alias.\n");
		}
		return 1;
	}
	else if (command[0].compare("unalias") == 0){
		if (command.size() == 2){
			runUNALIAS(command[1]);
		}
		else{
			printf("Error, incorrect number of arguments for unalias.\n");
		}
		return 1;
	}
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
	return 1;
}
int runCommand(){
	executeCommand(commandList);
	for (int i = 0; i < pipeList.size(); i++){
		executeCommand(pipeList[i]);
	}
}