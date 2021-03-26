#include <stdio.h>
#include "nutshscanner.h"
int yylex();
extern char* yytext;

void print_line(int line){
	printf("%4d | ",line);
}

int main(){
	print_line(1);
	
	int line = 1;
	
	while (1){
		int token = yylex();
		if (token == 0){
			break;
		}
		else{
			printf("scanned");
		}
		/*if (token == STRING_LITERAL){
			
		}
		else if (token == NUMBER_LITERAL){
			
		}
		else if (token == BOOLEAN_LITERAL){
			
		}
		else if (token == NULL_LITERAL){
			
		}
		else{
			
		}*/
	}
	printf("\n");
	return 0;
}