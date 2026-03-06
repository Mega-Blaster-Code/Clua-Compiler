local module = {}

local tokens = {
	-- ========= GENERIC
	SEMICOLON = "__SEMICOLON",
	STRING_LITERAL = "__STRING_LITERAL",
	CHAR_LITERAL = "__CHAR_LITERAL",
	NAME = "__NAME",
	EQUAL_ASSIGNING = "__EQUAL_ASSIGNING",
	OPEN_PARENTHESES = "__OPEN_PARENTHESES",
	CLOSE_PARENTHESES = "__CLOSE_PARENTHESES",
	OPEN_BRACKETS = "__OPEN_BRACKETS",
	CLOSE_BRACKETS = "__CLOSE_BRACKETS",
	OPEN_BRACES = "__OPEN_BRACES",
	CLOSE_BRACES = "__CLOSE_BRACES",
	COMMA = "__COMMA",
	DOT = "__DOT",
	COLON = "__COLON",
	DOUBLE_COLON = "__COLON",
	PREPROCESSOR_TOKEN = "__PREPROCESSOR_TOKEN",

	NEW_LINE = "__NEW_LINE",
	TAB = "__TAB",

	AMPERSAND = "__AMPERSAND",
	HASH_TAG = "__HASH_TAG",

	POINTER = "__POINTER",

	
	LINE_COMMENT = "__LINE_COMMENT",
	--MULT_LINE_COMMENT = "__LINE_COMMENT",

	-- ========= KEY WORDS
	IF = "__IF",
	ELSE = "__ELSE",
	ELSEIF = "__ELSEIF",
	THEN = "__THEN",
	FOR = "__FOR",
	DO = "__DO",
	WHILE = "__WHILE",
	BREAK = "__BREAK",
	FALSE = "__FALSE",
	TRUE = "__TRUE",
	NIL = "__NIL",
	END = "__END",
	FUNCTION = "__FUNCTION",
	RETURN = "__RETURN",
	ENUM = "__ENUM",
	EXTERN = "__EXTERN",
	EXEND = "__EXEND",

	-- ========= MATH

	MINUS = "__MINUS",
	PLUS = "__PLUS",
	ASTERISK = "__ASTERISK",
	DIVIDE = "__DIVIDE",
	INT_DIVIDE = "__INT_DIVIDE",
	MODULE = "__MODULE",

	-- ========= COMPARISON
	EQUAL_COMPARISON = "__EQUAL_COMPARISON",
	GREATER_OR_EQUAL = "__GREATER_OR_EQUAL",
	GREATER = "__GREATER",
	LOWER_OR_EQUAL = "__LOWER_OR_EQUAL",
	LOWER = "__LOWER",
	DIFFERENT = "__DIFFERENT",
	OR = "__OR",
	AND = "__AND",
	NOT = "__NOT",

	RAW_C = "__RAW_C",

	-- ========= NUMBER (int's can be only (int, char, long, long or short). float's can only be (float and double)) 

	NUMBER_INT = "__NUMBER_INT",
	NUMBER_FLOAT = "__NUMBER_FLOAT",

	-- ========= TYPES
	INT = "__INT",
	CHAR = "__CHAR",
	FLOAT = "__FLOAT",
	DOUBLE = "__DOUBLE",
	LONG = "__LONG",
	SHORT = "__SHORT",
	VOID = "__VOID",
	BOOL = "__BOOL",
	STRUCT = "__STRUCT",
	TYPEDEF = "__TYPEDEF",
	--SIZEOF = "__SIZEOF", -- stdio.h

	-- ========= QUALIFIERS
	SIGNED = "__SIGNED",
	UNSIGNED = "__UNSIGNED",
	CONST = "__CONST",
	VOLATILE = "__VOLATILE",
	OUTSIDE = "__OUTSIDE",
	STATIC = "__STATIC",
}

local keywords = {
	["if"] = tokens.IF,
	["elseif"] = tokens.ELSEIF,
	["else"] = tokens.ELSE,
	["then"] = tokens.THEN,
	["for"] = tokens.FOR,
	["do"] = tokens.DO,
	["break"] = tokens.BREAK,
	["while"] = tokens.WHILE,
	["end"] = tokens.END,
	["function"] = tokens.FUNCTION,
	["return"] = tokens.RETURN,
	["enum"] = tokens.ENUM,
	["extern"] = tokens.EXTERN,

	["true"] = tokens.TRUE,
	["false"] = tokens.FALSE,

	["nil"] = tokens.NIL,

	["or"] = tokens.OR,
	["and"] = tokens.AND,
	["not"] = tokens.NOT,

	int = tokens.INT,
	char = tokens.CHAR,
	float = tokens.FLOAT,
	double = tokens.DOUBLE,
	long = tokens.LONG,
	short = tokens.SHORT,
	void = tokens.VOID,
	bool = tokens.BOOL,
	struct = tokens.STRUCT,
	size_t = tokens.SIZE_T,

	-- ========= QUALIFIERS
	signed = tokens.SIGNED,
	unsigned = tokens.UNSIGNED,
	const = tokens.CONST,
	volatile = tokens.VOLATILE,
	outside = tokens.OUTSIDE,
	static = tokens.STATIC,
}

return {tokens, keywords}