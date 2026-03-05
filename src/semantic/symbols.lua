local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")

local AST_SPEC, KINDS

do
	local info = require("ASTkinds")
	AST_SPEC, KINDS = info[1], info[2]
end

local types = require("semantic.types")

local _SEMANTIC = _SEMANTIC

local _M = {}

_M.scopes = {}

_M.functions = {}

local SCOPE = {}
SCOPE.__index = SCOPE

local _n_of_scope = 0

function _M.newScope(name)
	local self = setmetatable({}, SCOPE)
	
	self.name = name or "__SCOPE" .. _n_of_scope
	
	_n_of_scope = _n_of_scope + 1

	self.is_loop = false
	self.is_function = false

	self.has_return = false

	self.variables = {}

	return self
end

function SCOPE:getVariable(name)
	return self.variables[name]
end

function SCOPE:declareVariable(name, t)
	self.variables[name] = t
end

function _M.pushScope(scope, name)
	local s = scope or _M.newScope(name)
	_M.scopes[#_M.scopes + 1] = s
	print("PUSH", s.name)
	return s
end

function _M.popScope()
	if #_M.scopes <= 0 then
		_SEMANTIC.SERROR("Attempt to close global scope")
	end
	
	local s = _M.scopes[#_M.scopes]
	print("POP", s.name)

	if s.is_function then
		if not s.has_return then
			_SEMANTIC.SERROR("Function don't have a final return")
		end
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
	return nil
end

function _M.declareVariable(name, t)
	if _M.findVariableInLocalScope(name) then
		_SEMANTIC.SERROR(string.format("Variable \"%s\" is already declared in local scope", name))
	end

	local local_scope = _M.getLocalScope()
	local_scope:declareVariable(name, t)

	return true
end

function _M.declareFunction(name, t)
	if #_M.scopes > 1 then
		_SEMANTIC.SERROR(string.format("Can't define function inside of a scope depth %d", #_M.scopes))
	end
	local f = _M.functions[name]

	if f then

		if f.prototype and t.prototype then
			_SEMANTIC.SERROR(string.format("Function \"%s\" has two prototypes", name))
		end

		if not f.prototype then
			_SEMANTIC.SERROR(string.format("Function \"%s\" is already declared", name))
		end

		if f.prototype then
			if not types.lowEquals(f, t) then
				_SEMANTIC.SERROR(string.format("Function \"%s\" prototype don't match declaration", name))
			end
		end

	end

	_M.functions[name] = t
end

function _M.findFunction(name)
	return _M.functions[name]
end

function _M.ancestralScopeIs()
	for i = #_M.scopes, 1, -1 do
		local scope = _M.scopes[i]
		if scope.is_loop or scope.is_function then
			return scope
		end
	end
	return nil
end

return _M