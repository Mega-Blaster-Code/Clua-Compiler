local _M = {}

local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")

local AST_SPEC, KINDS

do
    local info = require("ASTkinds")
    AST_SPEC, KINDS = info[1], info[2]
end

local semantic = {}
semantic.__index = semantic

function _M.new(file_path, AST, ARGUMENTS)
	local self = setmetatable({}, semantic)

	self.file_path = file_path

	self.ARGUMENTS = ARGUMENTS

	self.line = 0
	self.column = 0

	if not AST then
		self:error("no AST")
	end

	if AST.kind ~= KINDS.PROGRAM or not AST.body then
		self:error("no program '__PROGRAM'")
	end

	
	self.AST = AST.body

	self.pos = 1

	self.scope = {}

	return self
end

function semantic:peek()
	return self.AST[self.pos]
end

function semantic:Econsume()
	local s = self:peek()

	if not s then
		self:error("No consume")
	end

	if s.__line_info then
		self.line = s.__line_info.line
		self.column = s.__line_info.column
	end
	self.pos = self.pos + 1

	return s
end

function semantic:consume()
	local s = self:peek()
	if s.__line_info then
		self.line = s.__line_info.line
		self.column = s.__line_info.column
	end
	self.pos = self.pos + 1
	return s
end

function semantic:expect(kind)
	local s = self:peek()
	if not s then
		return false
	end
	if s.kind ~= kind then
		return false
	end
	
	return s
end

function semantic:Cexpect(kind)
	local s = self:peek()
	if not s then
		return false
	end
	if s.kind ~= kind then
		return false
	end
	return self:consume()
end

function semantic:Eexpect(kind)
	local s = self:peek()
	if not s then
		self:error(string.format("expected ['%s'] but got ['nil']", kind))
	end
	if s.kind ~= kind then
		self:error(string.format("expected ['%s'] but got ['%s']", kind, s.kind))
	end
	return s
end

function semantic:CEexpect(kind)
	local s = self:peek()
	if s.kind ~= kind then
		return false
	end
	return self:consume()
end

function semantic:error(msg)
    local line = self.line
    local column = self.column

    local message = {}

    message[#message + 1] = (string.format("SINTAX ERROR ['%s'] line %s column %s\n", self.file_path, line, column))
    message[#message + 1] = (msg)
    message[#message + 1] = ("\n")

    message = table.concat(message)

    self.ARGUMENTS:ERROR(message)
end

function semantic:warn(msg)
    local line = self.line
    local column = self.column
    local message = {}

    message[#message + 1] = (string.format("PARSER ['%s'] line %s column %s\n", self.file_path, line, column))
    message[#message + 1] = (msg)
    message[#message + 1] = ("\n")

    message = table.concat(message)

    self.ARGUMENTS:WARN(message)
end

function semantic:notification(msg)
    local line = self.line
    local column = self.column

    local message = {}

    message[#message + 1] = (string.format("PARSER ['%s'] line %s column %s\n", self.file_path, line, column))
    message[#message + 1] = (msg)
    message[#message + 1] = ("\n")

    local message = table.concat(message)

    self.ARGUMENTS:INFO(message)
end

function semantic:get_scope()
	return self.scope[#self.scope]
end

function semantic:push_scope()
	self.scope[#self.scope + 1] = {
		variables = {},
	}
end

function semantic:pop_scope()
	self.scope[#self.scope] = nil
end

function semantic:get_expression(expression)
	if expression.kind == KINDS.LITERAL_INT then
		return expression.kind
	elseif expression.kind == KINDS.LITERAL_FLOAT then
		return expression.kind
	elseif expression.kind == KINDS.LITERAL_STRING then
		return expression.kind
	elseif expression.kind == KINDS.LITERAL_CHAR then
		return expression.kind
	elseif expression.kind == KINDS.BINARY_EXPRESSION then
		local left = self:get_expression(expression.left)
		local right = self:get_expression(expression.right)
		if left.kind ~= right.kind then
			self:error(string.format("Binary expression with [%s](%s) and [%s](%s)", tostring(left.value), left.kind, tostring(right.value), right.kind))
		end
		return left.kind
	end
end

function semantic:define(type, qualifiers, modifiers, name, value_expression)
	local local_scope = self:get_scope()

	local_scope.variables[name] = {
		qualifiers = qualifiers,
		modifiers = modifiers,
		name = name,
		value = value_expression,
	}
end

local types_to_kinds = {
	["int"] = KINDS.LITERAL_INT,
	["float"] = KINDS.LITERAL_FLOAT,
	["double"] = KINDS.LITERAL_FLOAT,
	["char"] = KINDS.LITERAL_INT,
}

function semantic:is_pointer_var(var)
	if not var.modifiers[1] then
		return false
	end

	if not (var.modifiers[1].kind == KINDS.POINTER_MODIFIER) then
		return false
	end

	return true
end

function semantic:check_var_declaration()
	local declaration = self:Econsume()
	local expression_result = self:get_expression(declaration.value)

	local _type = declaration.type
	print(inspect(expression_result), _type)

	if types_to_kinds[_type] then
		if types_to_kinds[_type] ~= expression_result then
			self:error(string.format("Type error. declaring a '%s' with a '%s'", _type, expression_result))
		end
	end

	if _type == "void" then
		if not self:is_pointer_var(declaration) then
			self:error("Type error. void needs to be a pointer")
		end
	end

end

function semantic:start()
	while self:peek() do
		if self:expect(KINDS.VAR_DECLARATION) then
			self:check_var_declaration()
		end
	end
end

return _M