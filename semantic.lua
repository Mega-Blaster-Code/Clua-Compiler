local _M = {}

local PRE_TOKENS, KEYWORDS

do
    local info = require("tokens")
    PRE_TOKENS, KEYWORDS = info[1], info[2]
end

local semantic = {}
semantic.__index = semantic

local scope = {}
scope.__index = scope

function _M.new(AST)
	local self = setmetatable({}, semantic)

	self.AST = {}

	return self
end

function semantic:new_scope(parent)
	
end

function scope:new_variable(scope)
	
end

return _M