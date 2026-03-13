local _M = {}

local _flags = {}
_flags.__index = _flags

function _M.new(arg)
	local self = setmetatable({}, _flags)

	self.args = arg
	self.pos = 1

	self:start()

	return self
end

function _flags:error_write(...)
	
end

function _flags:consume()
	local t = self.args[self.pos]
	self.pos = self.pos + 1
	return t
end

function _flags:peek()
	return self.args[self.pos]
end

function _flags:tokinize()
	
end

function _flags:start()
	self:tokinize()
	while self:peek() do
		local argument = self:peek()

		self:consume()
	end
end

return _M