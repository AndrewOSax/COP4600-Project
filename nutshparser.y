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
#include<fcntl.h>
#define READ_END 0
#define WRITE_END 1
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
std::string firstExpand(std::string input, bool PATHParsing);
int executeCommand(std::vector<std::string> &command, int* pipein, int* pipeout);
int runCommand();
void clearCommand();
std::vector<std::string> commandList;
std::vector<std::string> pipeCommandList;
std::vector<std::vector<std::string>> pipeList;
FILE* stdinFile;
FILE* stdoutFile;
FILE* stderrFile;
bool background;
int pipeCount;
int** fd;
void pipeChild(int* pipein, int* pipeout);
void pipeParent(int* pipein, int* pipeout);
%}

%union {char* string;}
%start cmd_line
%token <string> WORD NEWLINE META BASIC_PIPE PIPE_IN PIPE_OUT PIPE_OUT_OUT PIPE_ERR PIPE_ERR_OUT AND
%%

cmd_line:
	command pipes pipein pipeout pipeerr wait NEWLINE {firstWord = true; runCommand(); clearCommand(); return 1;}
	| NEWLINE {firstWord = true; return 1;}
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
	| PIPE_IN WORD {stdinFile = fopen($2,"r");}
	;
pipeout:
	%empty
	| PIPE_OUT WORD {stdoutFile = fopen($2,"w");}
	| PIPE_OUT_OUT WORD {stdoutFile = fopen($2,"a");}
	;
pipeerr:
	%empty
	| PIPE_ERR WORD {stderrFile = fopen($2,"w");}
	| PIPE_ERR_OUT {stderrFile = stdoutFile;}
	;
wait:
	%empty
	| AND {background = true;}
	;
%%
void clearCommand(){
	commandList.clear();
	pipeCommandList.clear();
	pipeList.clear();
	if (stdinFile != nullptr){
		fclose(stdinFile);
		stdinFile = nullptr;
	}
	if (stdoutFile != nullptr && stderrFile != nullptr && stdoutFile == stderrFile){
		fclose(stdoutFile);
		stdoutFile = nullptr;
		stderrFile = nullptr;
	}
	else{
		if (stdoutFile != nullptr){
			fclose(stdoutFile);
			stdoutFile = nullptr;
		}
		if (stderrFile != nullptr){
			fclose(stderrFile);
			stderrFile = nullptr;
		}
	}	
	background = false;
}
int yyerror(char *s){
	fprintf(stderr,"%s\n",s);
	return 0;
}

int runCD(std::string dir){
	dir = firstExpand(dir,false);
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
				aliasTable[".."] = "/";
			}
		}
		else{
			fprintf(stderr,"Error: directory not found.\n");
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
				aliasTable[".."] = "/";
			}
		}
		else{
			fprintf(stderr,"Error: directory not found.\n");
            return 1;
		}
	}
	return 1;
}
std::string firstExpand(std::string input,bool PATHParsing){ //Tilde, dot, and dotdot expansion
	if (input.substr(0,1).compare("~") == 0){
		std::string output = varTable["HOME"];
		output += input.substr(1,input.size()-1);
		return output;
	}
	else if (!PATHParsing && input.substr(0,2).compare("..") == 0){
		int count = 1;
		while (3*count < input.size() && input.substr(3*count,2).compare("..") == 0){
			count++;
		}
		std::string output = aliasTable[".."];
		for (int i = 1; i < count; i++){
			int found = output.rfind("/");
			if (found != -1){
				output = output.substr(0,found);
			}
			else{
				output = "/";
			}
		}		
		output += input.substr(3*count-1,input.size());
		return output;
	}
	else if (!PATHParsing && input.substr(0,1).compare(".") == 0){
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
		fprintf(stdout,"%s=%s\n",i->first.c_str(),i->second.c_str());
	}
	return 1;
}
int runUNSETENV(std::string var){
	if (var.compare("PWD") == 0 || var.compare("HOME") == 0 || var.compare("PROMPT") == 0 || var.compare("PATH") == 0){
		fprintf(stderr,"Error: cannot unset variable \"%s\".\n",var.c_str());
		return 1;
	}
	varTable.erase(var);
	return 1;
}
int listAlias(){
	for (auto i = aliasTable.begin(); i != aliasTable.end(); i++) {
		if (i->first.compare(".") != 0 && i->first.compare("..") != 0){
			fprintf(stdout,"%s=%s\n",i->first.c_str(),i->second.c_str());
		}
	}
	return 1;
}
int runALIAS(std::string name, std::string val){
	if (name.compare(".") == 0 || name.compare("..") == 0){
		fprintf(stderr,"Error: cannot manually change alias \"%s\".\n",name.c_str());
		return 1;
	}
	if(name.compare(val) == 0){
		fprintf(stderr,"Error: expansion of \"%s\" would create a loop.\n", name.c_str());
	}
	else{
		auto iter = aliasTable.find(val);
		while (iter != aliasTable.end()){
			std::string alias = iter->second;
			if(name.compare(alias) == 0){
				fprintf(stderr,"Error: expansion of \"%s\" would create a loop.\n", name.c_str());
				return 1;
			}
			iter = aliasTable.find(alias);
		}
		aliasTable[name] = val;	
	}
	return 1;
}
int runUNALIAS(std::string name){
	if (name.compare(".") == 0 || name.compare("..") == 0){
		fprintf(stderr,"Error: cannot unset alias \"%s\".\n",name.c_str());
		return 1;
	}
	aliasTable.erase(name);
	return 1;
}
void pipeChild(int* pipein, int* pipeout){
	if (pipein != nullptr){
		dup2(pipein[READ_END], STDIN_FILENO);
		close(pipein[WRITE_END]);
		close(pipein[READ_END]);
	}
	else if (stdinFile != nullptr){					
		dup2(fileno(stdinFile),STDIN_FILENO);
	}
	if (pipeout != nullptr){
		dup2(pipeout[WRITE_END], STDOUT_FILENO);					
		close(pipeout[READ_END]);
		close(pipeout[WRITE_END]);
	}
	else if (stdoutFile != nullptr){					
		dup2(fileno(stdoutFile),STDOUT_FILENO);
	}
}
void pipeParent(int* pipein, int* pipeout){
	if (pipein != nullptr){
		close(pipein[READ_END]);
		close(pipein[WRITE_END]);
	}
	if (pipeout != nullptr){
		if (pipeCount != pipeList.size()-1){
			pipeCount++;
			pipe(fd[pipeCount]);
			executeCommand(pipeList[pipeCount-1],pipeout,fd[pipeCount]);
		}
		else{
			pipeCount++;
			executeCommand(pipeList[pipeCount-1],pipeout,nullptr);
		}	
		close(pipeout[WRITE_END]);					
		close(pipeout[READ_END]);
	}
}
int executeCommand(std::vector<std::string> &command, int* pipein, int* pipeout){
	command[0] = firstExpand(command[0],false);
	if (command[0].compare("bye") == 0){
		exit(1);
		return 1;
	}
	else if (command[0].compare("cd") == 0){
		if (command.size() == 1){
			if (pipein != nullptr){
				close(pipein[READ_END]);
				close(pipein[WRITE_END]);
			}
			runCD(varTable["HOME"]);
		}
		else if (command.size() == 2){
			if (pipein != nullptr){
				close(pipein[READ_END]);
				close(pipein[WRITE_END]);
			}
			runCD(command[1]);
		}
		else{
			fprintf(stderr,"Error: incorrect number of arguments for \"cd\".\n");
		}		
		return 1;
	}
	else if (command[0].compare("setenv") == 0){
		if (command.size() == 3){
			if (pipein != nullptr){
				close(pipein[READ_END]);
				close(pipein[WRITE_END]);
			}
			runSETENV(command[1],command[2]);
		}
		else{
			fprintf(stderr,"Error: incorrect number of arguments for \"setenv\".\n");
		}		
		return 1;
	}
	else if (command[0].compare("printenv") == 0){		
		if (command.size() == 1){
			if (pipein != nullptr){
				close(pipein[READ_END]);
				close(pipein[WRITE_END]);
			}
			int orig = dup(STDOUT_FILENO);
			if (pipeout == nullptr && stdoutFile != nullptr){					
				dup2(fileno(stdoutFile),STDOUT_FILENO);
			}			
			runPRINTENV();
			if (pipeout == nullptr && stdoutFile != nullptr){
				dup2(orig,STDOUT_FILENO);
			}
		}
		else{
			fprintf(stderr,"Error: incorrect number of arguments for \"printenv\".\n");
		}
		return 1;
	}
	else if (command[0].compare("unsetenv") == 0){
		if (command.size() == 2){
			if (pipein != nullptr){
				close(pipein[READ_END]);
				close(pipein[WRITE_END]);
			}
			runUNSETENV(command[1]);
		}
		else{
			fprintf(stderr,"Error: incorrect number of arguments for \"unsetenv\".\n");
		}
		return 1;
	}
	else if (command[0].compare("alias") == 0){
		if (command.size() == 1){
			if (pipein != nullptr){
				close(pipein[READ_END]);
				close(pipein[WRITE_END]);
			}
			int orig = dup(STDOUT_FILENO);
			if (pipeout == nullptr && stdoutFile != nullptr){					
				dup2(fileno(stdoutFile),STDOUT_FILENO);
			}			
			listAlias();
			if (pipeout == nullptr && stdoutFile != nullptr){
				dup2(orig,STDOUT_FILENO);
			}
		}
		else if (command.size() == 3){
			runALIAS(command[1],command[2]);
		}
		else{
			fprintf(stderr,"Error: incorrect number of arguments for \"alias\".\n");
		}
		return 1;
	}
	else if (command[0].compare("unalias") == 0){
		if (command.size() == 2){
			if (pipein != nullptr){
				close(pipein[READ_END]);
				close(pipein[WRITE_END]);
			}
			runUNALIAS(command[1]);
		}
		else{
			fprintf(stderr,"Error: incorrect number of arguments for \"unalias\".\n");
		}
		return 1;
	}
	else if (command[0][0] != '/') { // cmd is relative path
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
							fprintf(stderr, "fork() failed" );
							return 1;
						}
						else if (p == 0){
							pipeChild(pipein,pipeout);
							execv(args[0],args);
							fprintf(stderr,"Error: failed to execute command \"%s\"\n",args[0]);
							exit(0);
						}
						else{
							pipeParent(pipein,pipeout);
							if (!background){
								waitpid(p,&status,0);
							}
						}
						closedir(dp);
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
						fprintf(stderr, "fork() failed" );
						return 1;
					}
					else if (p == 0){
						pipeChild(pipein,pipeout);
						execv(args[0],args);
						fprintf(stderr,"Error: failed to execute command \"%s\"\n",args[0]);
						exit(0);
					}
					else{
						pipeParent(pipein,pipeout);
						if (!background){
							waitpid(p,&status,0);
						}
					}
					closedir(dp);
					return 1;
				}
			}
		}
		closedir(dp);
		fprintf(stderr,"Error: command \"%s\" not found.\n",command[0].c_str());
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
						fprintf(stderr, "fork() failed" );
						return 1;
					}
					else if (p == 0){
						pipeChild(pipein,pipeout);
						execv(args[0],args);
						fprintf(stderr,"Error: failed to execute command \"%s\"\n",args[0]);
						exit(0);
					}
					else{
						pipeParent(pipein,pipeout);
						if (!background){
							waitpid(p,&status,0);
						}
					}
					closedir(dp);
					return 1;
				}
			}
		}
		fprintf(stderr,"Error: command \"%s\" not found.\n",command[0].c_str());
	}
	return 1;
}
int runCommand(){
	if (stderrFile != nullptr){						
		dup2(fileno(stderrFile),STDERR_FILENO);
	}
	if (pipeList.size() != 0){
		fd = new int*[pipeList.size()];
		for(int i = 0; i < pipeList.size(); i++){
			fd[i] = new int[2];
		}
		pipeCount = 0;
		pipe(fd[pipeCount]);
		executeCommand(commandList,nullptr,fd[pipeCount]);
	}
	else{
		executeCommand(commandList,nullptr,nullptr);
	}
}