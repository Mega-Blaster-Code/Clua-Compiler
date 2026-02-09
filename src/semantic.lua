local _M = {}

local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")

local AST_SPEC, KINDS

do
    local info = require("ASTkinds")
    AST_SPEC, KINDS = info[1], info[2]
end

local __integers = {
	int = true,
	char = true,
	uchar = true,
	uint = true
}

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

function semantic:typeInClass(_type, class)
	return class[_type] or false
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
	["int"] = {KINDS.LITERAL_INT},
	["float"] = {KINDS.LITERAL_FLOAT},
	["double"] = {KINDS.LITERAL_FLOAT},
	["char"] = {KINDS.LITERAL_CHAR, KINDS.LITERAL_INT},
}

--[[

char            = 8 
int             = 32
int short       = 16
int long        = 64
int long long   = 64

]]

local types_size = {
	["int"] = {size = 16, min = -2147483648, max = 2147483647},
	["char"] = {size = 8, min = -128, max = 127},
	["uint"] = {size = 16, min = 0, max = 4294967295},
	["uchar"] = {size = 8, min = 0, max = 255},
}

local LIMITS = {
    float = {
        min = -3.402823466e38,
        max =  3.402823466e38,
        mantissa_bits = 24,
        integer = false
    },

    double = {
        min = -1.7976931348623157e308,
        max =  1.7976931348623157e308,
        mantissa_bits = 53,
        integer = false
    }
}

function semantic:isPointerDeclaration(declaration)
	if not declaration.modifiers[1] then
		return false
	end

	for i, v in ipairs(declaration.modifiers) do
		if v.kind == KINDS.POINTER_MODIFIER then
			return true
		end
	end

	if declaration.modifiers[1].kind == KINDS.POINTER_MODIFIER then
		--return true
	end

	return false
end

function semantic:getDeclarationVarSize(declaration)
	if self:typeInClass(declaration.type, __integers) then
		
		local size = types_size[declaration.type]
		print(inspect(size))
		
		for i, qual in ipairs(declaration.qualifiers) do
			
		end
	else
		
	end
end

function semantic:CheckVarFromInit(declaration, expression_result, expect, receive)
	if self:isPointerDeclaration(declaration) then
		-- void pointer or something else

		if expect == KINDS.LITERAL_CHAR then
			print("CHAR POINTER", receive)
			if receive == KINDS.LITERAL_STRING then
				return true, nil
			end
		end

		return false, ("Type error. expected a pointer expression")
	else
		if expect == "void" then
			return false, ("Type error. void needs to be a pointer")
		end
	end

	if expect ~= receive then
		return false, string.format("Type error. declaring a '%s' with a '%s'", expect, receive)
	end

	return true, nil
end

function semantic:CheckVarDeclaration()
	local declaration = self:Econsume()
	local expression_result = self:get_expression(declaration.value)

	local _types = types_to_kinds[declaration.type]

	local err = nil

	--print(_types)

	for i, _type in ipairs(_types) do
		local correct, e = self:CheckVarFromInit(declaration, expression_result, _type, expression_result)
		if correct then
			err = nil
			break
		end
		err = e
	end

	if err then
		self:error(err)
	end

	self:getDeclarationVarSize(declaration)

	print(inspect(expression_result), _types, err)
	
end

function semantic:start()
	while self:peek() do
		if self:expect(KINDS.VAR_DECLARATION) then
			self:CheckVarDeclaration()
		end
	end
end

return _M