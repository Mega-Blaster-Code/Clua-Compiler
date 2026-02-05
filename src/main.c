#include <stdio.h>
#include <stdlib.h>
#include "filereader.h"
#include "lexer.h"

int main(int argc, char** argv){
	for(int i = 0; i < argc; i++){
		printf("%d: \"%s\"\n", i, argv[i]);
	}

	if(argc < 2){
		fprintf(stderr, "No input file");
		return -1;
	}

	size_t file_size = 0;

	char* file_contents = FRread(argv[1], FR_READ_BINARY, &file_size);
	
	if(file_contents == NULL){
		fprintf(stderr, "Input file \"%s\" don't exist", argv[1]);
		return -1;
	}

	printf("\n", file_contents);

	LEXER l = Lnew_lexer(file_contents, file_size);

	printf("lexer {\n\ttokens_pointer = %zu,\n\ttokens_size = %zu,\n\tcontent_size = %zu,\n\tcontent = \"%s\"\n}",
		l.tokens_pointer,
	 	l.tokens_size,
		l.contents_size,
		l.contents
	);

	free(file_contents);

	return 0;
}