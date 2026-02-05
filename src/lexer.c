//#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lexer.h"
//#include "local_arena.h"

/*
enum TOKENS_TYPE{
	NAME,
	LITERAL_FLOAT,
	LITERAL_INT,
};

typedef struct TOKEN{
	size_t line;
	size_t column;
	const char* buffer;
	enum TOKENS_TYPE token_type;
} TOKEN;

typedef struct LEXER{
	Arena arena;
	TOKEN *tokens;
	char *contents;
	size_t contents_size;

	char *buffer;
	size_t buffer_size;
} LEXER;
*/

LEXER Lnew_lexer(char* content, size_t content_size){
	LEXER l;
	l.contents = content;
	l.contents_size = content_size;

	l.line = 0;
	l.column = 0;

	l.buffer = calloc(9, sizeof(unsigned char));
	l.buffer_size = 9;
	l.buffer_pointer = 0;

	l.tokens_pointer = 0;
	l.tokens_size = 8;

	l.tokens = calloc(l.tokens_size, sizeof(TOKEN));
	
	return l;
}

void Lgrow_buffer(LEXER *l){
	if(l->buffer_pointer < l->buffer_size - 1){
		l->buffer[l->buffer_pointer] = 0;
		return;
	}
	l->buffer_size = l->buffer_size * 2 + 1;
	l->buffer = realloc(l->buffer, l->buffer_size);
}

void Lgrow_tokens(LEXER *l){
	if(l->tokens_pointer < l->tokens_size){
		return;
	}
}

void Lpush_back (LEXER *l, const char _c){
	l->buffer[l->buffer_pointer++] = _c;
	Lgrow_buffer(l);
	l->buffer[l->buffer_size - 1] = 0;
}

void Lnew_token(LEXER *l){
	Lgrow_tokens(l);
	TOKEN *token = malloc(sizeof(TOKEN));

	token->line = l->line;
	token->column = l->column;
	token->token_type = __NAME;

	token->buffer = malloc(0);
	token->buffer = memcpy(token->buffer, l->buffer, l->buffer_pointer);
	token->buffer[l->buffer_pointer] = 0;
	l->buffer[0] = 0;
	l->buffer_pointer = 0;

	l->tokens[l->tokens_pointer++] = token;

	printf("token = {\n\ttype = %d\n\tline = %zu\n\tcolumn = %zu\n\tbuffer = \"%s\"\n}", token->token_type, token->line, token->column, token->buffer);
}