#include <stdlib.h>

#ifndef __CLUA_LEXER_H
#define __CLUA_LEXER_H

#include "safema.h"

enum TOKENS_TYPE{
	__NT = 0,
	__NAME, // 1
	__LITERAL_FLOAT, // 2
	__LITERAL_INT, // 3
	__SEMICOLON, // 4
	__DOT, // 5
	__EQUAL_ASSIGNING, // 6
	__INT, // 7
	__FLOAT, // 7
	__CHAR, // 7
	__DOUBLE, // 7
	__INT, // 7
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
	
	size_t pointer;
	
	char *buffer;
	size_t buffer_size;
	size_t buffer_pointer;
} LEXER;

void display_enum_printf(enum TOKENS_TYPE type);

LEXER Lnew_lexer(char* content, size_t content_size);

void Lfree(LEXER *lx);

void Lgrow_buffer(LEXER *lx);

void Lpush_back (LEXER *lx, const char _c);

void Lnew_token(LEXER *lx, enum TOKENS_TYPE type);

char Lpeek(LEXER *lx);

char LpeekAHead(LEXER *lx, size_t length);

char Lconsume(LEXER *lx);

void LstartLexer(LEXER *lx);

#endif