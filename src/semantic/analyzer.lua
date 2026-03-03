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

_M.scopes = {}

_M.functions = {}

local SCOPE = {}
SCOPE.__index = SCOPE

local _n_of_scope = 0

function _M.analyze()
	local self = setmetatable({}, SCOPE)

	self.name = "__SCOPE" .. _n_of_scope

	_n_of_scope = _n_of_scope + 1

	self.variables = {}

	return self
end

return _M