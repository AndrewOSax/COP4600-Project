#pragma once
#include <stdbool.h>
struct evTable {
   char var[256][256];
   char val[256][256];
};
struct aTable {
	char name[256][256];
	char val[256][256];
};

struct evTable varTable;
struct aTable aliasTable;

int aliasIndex, varIndex;
char* subAliases(char* name);

bool firstWord;