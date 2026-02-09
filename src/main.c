#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include "safema.h"
#include "filereader.h"
#include "lexer.h"

int main(void){
	/*for(int i = 0; i < argc; i++){
		printf("%d: \"%s\"\n", i, argv[i]);
	}

	if(argc < 2){
		fprintf(stderr, "No input file");
		return -1;
	}
	*/

	size_t file_size = 0;

	char* file_contents = FRread("test/code.clua", FR_READ_BINARY, &file_size);
	
	if(file_contents == NULL){
		fprintf(stderr, "Input file \"%s\" don't exist", "test/code.clua");
		return -1;
	}

	LEXER lx = Lnew_lexer(file_contents, file_size);

	LstartLexer(&lx);

	printf("lexer {\n\tpointer = %zu\n\ttokens_pointer = %zu,\n\ttokens_size = %zu,\n\tcontent_size = %zu,\n\tcontent = \"%s\"\n}\n",
		lx.pointer,
		lx.tokens_pointer,
	 	lx.tokens_size,
		lx.contents_size,
		lx.contents
	);

	for(size_t i = 0; i < lx.tokens_pointer; i++){
		TOKEN *token = lx.tokens[i];
		printf("%zu:%zu ['", token->line, token->column);
		display_enum_printf(token->token_type);
		printf("'] = \"%s\"\n", token->buffer);
	}

	free(file_contents);
	Lfree(&lx);

	return 0;
}