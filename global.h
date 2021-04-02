#pragma once

struct evTable {
   char var[256][100];
   char val[256][100];
};
struct aTable {
	char name[256][100];
	char val[256][100];
};

struct evTable varTable;
struct aTable aliasTable;

int aliasIndex, varIndex;
char* subAliases(char* name);