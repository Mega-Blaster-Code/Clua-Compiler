local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")

local AST_SPEC, KINDS

do
    local info = require("ASTkinds")
    AST_SPEC, KINDS = info[1], info[2]
end

local __SEMANTIC = _SEMANTIC
local types = __SEMANTIC.types
local _M = {}

local SCOPE = {}
SCOPE.__index = SCOPE

function _M.newScope()
	local self = setmetatable({}, SCOPE)
	return self
end

function _M.pushScope(scope)
	
end

function _M.popScope(scope)
	
end

function _M.declareVariable(t)
	
end

function _M.findVariable(name)
	
end

function _M.declareFunction(t)
	
end

function _M.findFunction(name)
	
end

return _M