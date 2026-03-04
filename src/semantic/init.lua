local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")

local AST_SPEC, KINDS

do
    local info = require("ASTkinds")
    AST_SPEC, KINDS = info[1], info[2]
end


local _M = {}

_SEMANTIC = _M

local analyzer = require("semantic.analyzer")
local expressions = require("semantic.expressions")
local semantic = require("semantic.semantic")
local symbols = require("semantic.symbols")
local types = require("semantic.types")

_M.analyzer = analyzer
_M.expressions = expressions
_M.semantic = semantic
_M.symbols = symbols
_M.types = types

local DECLARATIONS_KINDS = {
	[KINDS.FUNCTION_DECLARATION_PROTOTYPE] = true,
	[KINDS.FUNCTION_DECLARATION] = true,
	[KINDS.STRUCT_DECLARATION_PROTOTYPE] = true,
	[KINDS.STRUCT_DECLARATION] = true,
	[KINDS.FUNCTION_DECLARATION_PROTOTYPE] = true,
	[KINDS.FUNCTION_DECLARATION] = true,
	[KINDS.VAR_DECLARATION_PROTOTYPE] = true,
	[KINDS.VAR_DECLARATION] = true,
	[KINDS.STRUCT_VAR_DECLARATION] = true,
	[KINDS.STRUCT_INIT_VAR_DECLARATION] = true,
}


local STRUCT_DECLARATIONS_KINDS = {
	[KINDS.STRUCT_DECLARATION_PROTOTYPE] = true,
	[KINDS.STRUCT_DECLARATION] = true,
	[KINDS.STRUCT_VAR_DECLARATION] = true,
	[KINDS.STRUCT_INIT_VAR_DECLARATION] = true,
}

local VAR_DECLARATIONS_KINDS = {
	[KINDS.FUNCTION_DECLARATION_PROTOTYPE] = true,
	[KINDS.FUNCTION_DECLARATION] = true,
	[KINDS.VAR_DECLARATION_PROTOTYPE] = true,
	[KINDS.VAR_DECLARATION] = true,
	[KINDS.STRUCT_VAR_DECLARATION] = true,
	[KINDS.STRUCT_INIT_VAR_DECLARATION] = true,
}

local FUNCTION_DECLARATIONS_KINDS = {
	[KINDS.FUNCTION_DECLARATION_PROTOTYPE] = true,
	[KINDS.FUNCTION_DECLARATION] = true,
}

local function isDeclaration(kind, type)
	return type[kind] ~= nil
end

local semantic = {}
semantic.__index = semantic

local _s = _SEMANTIC

function _M.new(file_path, AST_TREE, ARGUMENTS)
	local self = setmetatable({}, semantic)

	self.file_path = file_path
	self.AST = AST_TREE
	self.ARGUMENTS = ARGUMENTS

	_s.ARGUMENTS = ARGUMENTS

	return self
end

function semantic:start()
	analyzer.analyze(self.AST)
end

local _SEMANTIC = _SEMANTIC

_G._SEMANTIC = nil

return _M