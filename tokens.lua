local module = {}

local tokens = {
	-- ========= GENERIC
	SEMICOLON = "__SEMICOLON",
	STRING = "__STRING",
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
	NEW_LINE = "__NEW_LINE",
	AMPERSAND = "__AMPERSAND",

	
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

	-- ========= MATH

	MINUS = "__MINUS",
	PLUS = "__PLUS",
	ASTERISK = "__ASTERISK",
	DIVIDE = "__DIVIDE",
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

	-- ========= NUMBER (int's can be only (int, char, long, long or short). float's can only be (float and double)) 

	NUMBER_INT = "__NUMBER_INT",
	NUMBER_FLOAT = "__NUMBER_FLOAT",

	-- ========= TYPES
	INT = "__INT",
	CHAR = "__CHAR",
	FLOAT = "__FLOAT",
	DOUBLE = "__DOUBLE",
	VOID = "__VOID",
	BOOL = "__BOOL",
	STRUCT = "__STRUCT",
	TYPEDEF = "__TYPEDEF",
	SIZE_T = "__SIZE_T", -- stdio.h

	-- ========= QUALIFIERS
	SIGNED = "__SIGNED",
	UNSIGNED = "__UNSIGNED",
	CONST = "__CONST",
	VOLATILE = "__VOLATILE",
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
	void = tokens.VOID,
	bool = tokens.BOOL,
	struct = tokens.STRUCT,
	size_t = tokens.SIZE_T, -- stdio.h

	-- ========= QUALIFIERS
	signed = tokens.SIGNED,
	unsigned = tokens.UNSIGNED,
	const = tokens.CONST,
	volatile = tokens.VOLATILE,
}

return {tokens, keywords}