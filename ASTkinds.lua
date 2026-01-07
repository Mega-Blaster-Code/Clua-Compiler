local PRE_TOKENS, KEYWORDS

do
    local info = require("tokens")
    PRE_TOKENS, KEYWORDS = info[1], info[2]
end

local AST_SPEC = {
  VarDecl = {
    fields = { "type", "name", "value" }
  },

  binaryExpr = {
	fields = {"op", "left", "right"}
  },

  IntLiteral = {
    fields = { "value" }
  },

  VarRef = {
    fields = { "name" }
  }
}

local kinds = {
	PROGRAM = "__PROGRAM",
	BLOCK = "__BLOCK",
	FUNCTION_DECLARATION = "__FUNCTION_DECLARATION",
	WHILE = "__WHILE",
	IF = "__IF",
	FOR = "__FOR",
	RAW_DO = "__RAW_DO",
	LITERAL_BOOL = "__LITERAL_BOOL",
	CALL_EXPRESSION = "__CALL_EXPRESSION",
	CUSTOM_VAR_DECLARATION = "__CUSTOM_VAR_DECLARATION",
	STRUCT_DECLARATION = "__STRUCT_DECLARATION",
	VAR_DECLARATION = "__VAR_DECLARATION",
	VAR_REDEFINITION = "__VAR_REDEFINITION",
	NULL_VAR_DECLARATION = "__NULL_VAR_DECLARATION",
	CUSTOM_NULL_VAR_DECLARATION = "__CUSTOM_NULL_VAR_DECLARATION",
	STRING_LITERAL = "__STRING_LITERAL",
	BINARY_EXPRESSION = "__BINARY_EXPRESSION",
	MODIFIER = "__MODIFIER",
	LITERAL = "__LITERAL",
	VAR_REF = "__VAR_REF",
	UNARY_EXPRESSION = "__UNARY_EXPRESSION",
	POINTER_DEREFERENCE = "__POINTER_DEREFERENCE",
	ADDRESS_OF = "__ADDRESS_OF",
	FIELD_ACCESS = "__FIELD_ACCESS",
}

-- VAR DECLARATION

-- <type> <name> <equal> <expression>

return {AST_SPEC, kinds}
