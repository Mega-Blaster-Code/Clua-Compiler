#include <stdlib.h>
//#include "local_arena.h"

#ifndef __CLUA_LEXER_H
#define __CLUA_LEXER_H

enum TOKENS_TYPE{
	__NAME,
	__LITERAL_FLOAT,
	__LITERAL_INT,
};

typedef struct TOKEN{
	size_t line;
	size_t column;
	char* buffer;
	enum TOKENS_TYPE token_type;
} TOKEN;

typedef struct LEXER{
	TOKEN **tokens;
	size_t tokens_size;
	size_t tokens_pointer;

	size_t line;
	size_t column;

	char *contents;
	size_t contents_size;
	
	char *buffer;
	size_t buffer_size;
	size_t buffer_pointer;
} LEXER;

LEXER Lnew_lexer(char* content, size_t content_size);

void Lgrow_buffer(LEXER *l);

void Lpush_back (LEXER *l, const char _c);

void Lnew_token(LEXER *l);

#endif