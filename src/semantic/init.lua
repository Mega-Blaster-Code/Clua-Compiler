local AST_SPEC, KINDS

do
    local info = require("ASTkinds")
    AST_SPEC, KINDS = info[1], info[2]
end

_SEMANTIC = {}

_SEMANTIC.analyzer = require("semantic.analyzer")
_SEMANTIC.context = require("semantic.context")
_SEMANTIC.expressions = require("semantic.expressions")
_SEMANTIC.literals = require("src.semantic.literals")
_SEMANTIC.semantic = require("semantic.semantic")
_SEMANTIC.statements = require("semantic.statements")
_SEMANTIC.symbols = require("semantic.symbols")
_SEMANTIC.types = require("semantic.types")

local semantic = {}
semantic.__index = semantic

function _SEMANTIC.new(file_path, AST_TREE, ARGUMENTS)
	local self = setmetatable({}, semantic)

	self.file_path = file_path
	self.AST = AST_TREE.body
	self.ARGUMENTS = ARGUMENTS

	return self
end


local _SEMANTIC = _SEMANTIC
_G._SEMANTIC = nil

function semantic:start()
	local old = nil
	for i = 1, #self.AST do
		local node = self.AST[i]
		if node.kind == KINDS.VAR_DECLARATION then
			local lold = _SEMANTIC.types.build(node)
		end
	end
	
end

return _SEMANTIC