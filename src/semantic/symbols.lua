local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")

local AST_SPEC, KINDS

do
    local info = require("ASTkinds")
    AST_SPEC, KINDS = info[1], info[2]
end

local _SEMANTIC = _SEMANTIC

local _M = {}

_M.scopes = {}

_M.functions = {}

local SCOPE = {}
SCOPE.__index = SCOPE

local _n_of_scope = 0

function _M.newScope()
	local self = setmetatable({}, SCOPE)

	self.name = "__SCOPE" .. _n_of_scope

	_n_of_scope = _n_of_scope + 1

	self.variables = {}

	return self
end

function SCOPE:getVariable(name)
	return self.variables[name]
end

function SCOPE:declareVariable(name, t)
	self.variables[name] = t
end

function _M.pushScope(scope)
	_M.scopes[#_M.scopes + 1] = scope or _M.newScope()
end

function _M.popScope()
	if #_M.scopes <= 0 then
		_SEMANTIC.ARGUMENTS:ERROR("Attempt to close global scope")
	end
	_M.scopes[#_M.scopes] = nil
	return true
end

function _M.getLocalScope()
	return _M.scopes[#_M.scopes]
end

function _M.findVariableInLocalScope(name)
	local local_scope = _M.getLocalScope()
	return local_scope:getVariable(name)
end

function _M.findVariable(name)
	for i = #_M.scopes, 1, -1 do
		local scope = _M.scopes[i]
		local var = scope:getVariable(name)
		if var then
			return var
		end
	end
end

function _M.declareVariable(name, t)
	if _M.findVariableInLocalScope(name) then
		_SEMANTIC.ARGUMENTS:ERROR(string.format("Variable \"%s\" is already declared in local scope", name))
	end

	local local_scope = _M.getLocalScope()
	local_scope:declareVariable(name, t)

	return true
end

function _M.declareFunction(name, t)
	if #_M.scopes > 1 then
		_SEMANTIC.ARGUMENTS:ERROR(string.format("Can't define function inside of a scope depth %d", #_M.scopes))
	end
	if _M.functions[name] then
		_SEMANTIC.ARGUMENTS:ERROR(string.format("Function \"%s\" is already declared", name))
	end
	_M.functions[name] = t
	return true
end

function _M.findFunction(name)
	return _M.functions[name]
end

return _M