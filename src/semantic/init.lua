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
local context = require("semantic.context")
local expressions = require("semantic.expressions")
local literals = require("src.semantic.literals")
local semantic = require("semantic.semantic")
local statements = require("semantic.statements")
local symbols = require("semantic.symbols")
local types = require("semantic.types")

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

function _M.new(file_path, AST_TREE, ARGUMENTS)
	local self = setmetatable({}, semantic)

	self.file_path = file_path
	self.AST = AST_TREE.body
	self.ARGUMENTS = ARGUMENTS

	return self
end

function semantic:start()
	for i = 1, #self.AST do
		local node = self.AST[i]
		if isDeclaration(node.kind, VAR_DECLARATIONS_KINDS) then
			local old = types.build(node)

			print(types.sizeof(old))
			print("======")
		end
	end
	
	
end

local _SEMANTIC = _SEMANTIC

_G._SEMANTIC = nil

return _M