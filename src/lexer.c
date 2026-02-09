#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ctype.h>
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

void display_enum_printf(enum TOKENS_TYPE type){
	switch (type){
	case __NT:
		printf("__NT");
		break;
	case __NAME:
		printf("__NAME");
		break;
	case __LITERAL_FLOAT:
		printf("__LITERAL_FLOAT");
		break;
	case __LITERAL_INT:
		printf("__LITERAL_INT");
		break;
	case __SEMICOLON:
		printf("__SEMICOLON");
		break;
	case __DOT:
		printf("__DOT");
		break;
	case __EQUAL_ASSIGNING:
		printf("___EQUAL_ASSIGNINGT");
		break;
	
	default:
		break;
	}
}

size_t remove_cr_buffer(char *buf, size_t size) {
    size_t w = 0;

    for (size_t r = 0; r < size; r++) {
        if (buf[r] != '\r') {
            buf[w++] = buf[r];
        }
    }

    return w; // novo tamanho
}

LEXER Lnew_lexer(char* content, size_t content_size){
	LEXER lx;
	remove_cr_buffer(content, content_size);
	lx.contents = content;

	for(size_t i = 0; i < content_size; i++){
		if(lx.contents[i] == '\r'){
			lx.contents[i] = '\1';
		}
	}

	lx.contents_size = content_size;


	lx.line = 0;
	lx.column = 0;

	lx.buffer = SMsafeCalloc(9, sizeof(unsigned char));

	lx.buffer_size = 9;
	lx.buffer_pointer = 0;

	lx.pointer = 0;

	lx.tokens_pointer = 0;
	lx.tokens_size = 8;

	lx.tokens = SMsafeCalloc(lx.tokens_size, sizeof(TOKEN));

	return lx;
}

void Lfree(LEXER *lx){
	free(lx->buffer);
	for(size_t i = 0; i < lx->tokens_pointer; i++){
		TOKEN *token = lx->tokens[i];
		free(token->buffer);
	}
}

void Lgrow_buffer(LEXER *lx){
	if(lx->buffer_pointer < lx->buffer_size - 2){
		lx->buffer[lx->buffer_pointer] = 0;
		return;
	}
	lx->buffer_size = lx->buffer_size * 2 + 1;
	lx->buffer = SMsafeRealloc(lx->buffer, lx->buffer_size);
}

void Lgrow_tokens(LEXER *lx){
	if(lx->tokens_pointer < lx->tokens_size){
		return;
	}
}

void Lpush_back (LEXER *lx, const char _c){
	Lgrow_buffer(lx);
	lx->buffer[lx->buffer_pointer++] = _c;
	lx->buffer[lx->buffer_pointer] = 0;
	lx->buffer[lx->buffer_size - 1] = 0;
}

void Lnew_token(LEXER *lx, enum TOKENS_TYPE type){
	Lgrow_tokens(lx);
	printf("before malloc\n");
	TOKEN *token = (TOKEN*)SMsafeMalloc(sizeof(TOKEN));

	printf("after malloc\n");

	token->line = lx->line;
	token->column = lx->column;

	token->column = lx->column;
	token->token_type = type;

	token->buffer = SMsafeMalloc(lx->buffer_pointer + 1);

	token->buffer = memcpy(token->buffer, lx->buffer, lx->buffer_pointer);
	token->buffer[lx->buffer_pointer] = 0;
	lx->buffer[0] = 0;
	lx->buffer_pointer = 0;

	lx->tokens[lx->tokens_pointer++] = token;
}

char Lpeek(LEXER *lx){
	if(lx->pointer > lx->contents_size){
		return 0;
	}
	return lx->contents[lx->pointer];
}

char LEpeek(LEXER *lx){
	if(lx->pointer >= lx->contents_size){
		fprintf(stderr, "Currupted file or incompleted code");
		exit(-5);
	}
	return lx->contents[lx->pointer];
}

char LpeekAHead(LEXER *lx, size_t length){
	if(lx->pointer + length >= lx->contents_size){
		return 0;
	}
	return lx->contents[lx->pointer + length];
}

char Lconsume(LEXER *lx){
	if(lx->pointer >= lx->contents_size){
		return 0;
	}
	printf("%zu %zu '%c'\n", lx->buffer_pointer, lx->buffer_size, Lpeek(lx));
	lx->column++;
	char _c = lx->contents[lx->pointer++];
	if(_c == '\n'){
		lx->column = 0;
		lx->line++;
	}
	return _c;
}

int LmatchPatternes(LEXER *lx){
	char _c = Lpeek(lx);
	if(iscntrl(_c) || isspace(_c)){
		while(LEpeek(lx) && (iscntrl(_c) || isspace(_c))){
			Lconsume(lx);
			_c = Lpeek(lx);
		}
		return 1;
	}
	if(isalpha(_c)){
		while(LEpeek(lx) && (isalnum(_c))){
			Lpush_back(lx, Lconsume(lx));
			_c = Lpeek(lx);
		}
		return 0;
	}
	if(_c == '.'){
		printf(".");
		if(LpeekAHead(lx, 1) && isdigit(LpeekAHead(lx, 1))){
			Lpush_back(lx, Lconsume(lx)); // '.'
			_c = Lpeek(lx);
			while(LEpeek(lx) && (isdigit(_c))){
				printf("%c", _c);
				Lpush_back(lx, Lconsume(lx));
				_c = Lpeek(lx);
			}
			Lnew_token(lx, __LITERAL_FLOAT);
			return 1;
		}
	}
	if(isdigit(_c)){ // integer || float (%d+.%d*)
		int is_float = 0;
		while(LEpeek(lx) && (isdigit(_c) || _c == '.')){
			if(_c == '.'){
				if(is_float){
					fprintf(stderr, "Invalid literal float %zu:%zu", lx->line, lx->column);
				}
				is_float = 1;
				Lpush_back(lx, Lconsume(lx));
			}else{
				Lpush_back(lx, Lconsume(lx));
			}
			_c = Lpeek(lx);
		}
		if(is_float){
			Lnew_token(lx, __LITERAL_FLOAT);
		}else{
			Lnew_token(lx, __LITERAL_INT);
		}
		return 1;
	}
	if(_c == '='){
		Lpush_back(lx, Lconsume(lx));
		Lnew_token(lx, __EQUAL_ASSIGNING);
		return 1;
	}
	if(_c == ';'){
		Lpush_back(lx, Lconsume(lx));
		Lnew_token(lx, __SEMICOLON);
		return 1;
	}
	if(_c == '.'){
		Lpush_back(lx, Lconsume(lx));
		Lnew_token(lx, __DOT);
		return 1;
	}
	fprintf(stderr, "No pattern ['%c']", _c);
	exit(-1);
	return 0;
}

void LstartLexer(LEXER *lx){
	while(Lpeek(lx)){
		int token_generated = LmatchPatternes(lx);
		if (token_generated){
			continue;
		}
		Lnew_token(lx, __NAME);
	}
}