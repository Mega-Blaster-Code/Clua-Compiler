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

local function createMessage(self, msg)
    local line = self.line
    local column = self.column

    local message = {}

    message[#message + 1] = (string.format("SEMANTIC ERROR ['%s'] line %s column %s\n", self.file_path, line, column))
    message[#message + 1] = (msg)
    message[#message + 1] = ("\n")

    message = table.concat(message)

    return message
end

function semantic:error(msg)
    local message = createMessage(self, msg)

    self.ARGUMENTS:ERROR(message)
end

function semantic:warn(msg)
    local message = createMessage(self, msg)

    self.ARGUMENTS:WARN(message)
end

function semantic:notification(msg)
    local message = createMessage(self, msg)

    self.ARGUMENTS:INFO(message)
end

function semantic:get_scope()
    return self.scope[#self.scope]
end

function semantic:push_scope()
    self.scope[#self.scope + 1] = {
        variables = {}
    }
end

function semantic:pop_scope()
    self.scope[#self.scope] = nil
end

function semantic:getExpression(expression)
    if expression.kind == KINDS.LITERAL_INT then
        return expression.kind, expression.value
    elseif expression.kind == KINDS.LITERAL_FLOAT then
        return expression.kind, expression.value
    elseif expression.kind == KINDS.LITERAL_STRING then
        return expression.kind, expression.value
    elseif expression.kind == KINDS.LITERAL_CHAR then
        return expression.kind, expression.value
    elseif expression.kind == KINDS.UNARY_EXPRESSION then
        local next, value = self:getExpression(expression.expr)

        if next == KINDS.LITERAL_INT or next == KINDS.LITERAL_FLOAT then
            return next, "-" .. value
        end
        return
    elseif expression.kind == KINDS.ADDRESS_OF then
		local next, value = self:getExpression(expression.expr)
        if expression.op == "&" then
            if next == KINDS.LITERAL_INT or next == KINDS.LITERAL_FLOAT then
                self:error("Can't get adress of a temporary literal value")
            end

            self:warn("TODO address")
            os.exit()
        end
    elseif expression.kind == KINDS.BINARY_EXPRESSION then
        local left = self:getExpression(expression.left)
        local right = self:getExpression(expression.right)
        if left.kind ~= right.kind then
            self:error(string.format("Binary expression with [%s](%s) and [%s](%s)", tostring(left.value), left.kind,
                tostring(right.value), right.kind))
        end
        return left.kind, expression.value
    end
end
function semantic:define(type, qualifiers, modifiers, name, value_expression)
    local local_scope = self:get_scope()

    local_scope.variables[name] = {
        qualifiers = qualifiers,
        modifiers = modifiers,
        name = name,
        value = value_expression
    }
end

local types_to_kinds = {
    ["int"] = {KINDS.LITERAL_INT},
    ["float"] = {KINDS.LITERAL_FLOAT},
    ["double"] = {KINDS.LITERAL_FLOAT},
    ["char"] = {KINDS.LITERAL_CHAR, KINDS.LITERAL_INT}
}

--[[

char            = 8 
int             = 32
int short       = 16
int long        = 64
int long long   = 64

]]

local types_size = {
    ["int"] = {
        size = 32,
        min = -2147483648,
        max = 2147483647
    },
    ["char"] = {
        size = 8,
        min = -128,
        max = 127
    },
    ["uint"] = {
        size = 32,
        min = 0,
        max = 4294967295
    },
    ["uchar"] = {
        size = 8,
        min = 0,
        max = 255
    }
}

local function countSignificantDigits(literal)
    literal = literal:gsub("^[+-]", "")

    local int, frac = literal:match("^(%d*)%.?(%d*)$")
    int = int or ""
    frac = frac or ""

    int = int:gsub("^0+", "")
    frac = frac:gsub("0+$", "")

    if int == "" and frac == "" then
        return 0
    end

    return #int + #frac
end

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
        -- return true
    end

    return false
end

function semantic:getDeclarationVarSize(declaration)
    if self:typeInClass(declaration.type, __integers) then

        local allsize = types_size[declaration.type]
        for i, qual in ipairs(declaration.qualifiers) do
            if qual.value == "unsigned" then
                allsize = types_size["u" .. declaration.type]
            end
        end

        local size = allsize.size

        for i, qual in ipairs(declaration.qualifiers) do
            if qual.value == "long" and size < 64 then
                size = size * 2
            end
            if qual.value == "short" and size > 8 then
                size = size // 2
            end
        end

        return allsize.max, allsize.min, size
    else
        local size = 7

        for i, qual in ipairs(declaration.qualifiers) do
            if qual.value == "double" and size < 64 then
                size = size * 2
            end
        end

        return size
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
    local expression_result, literal_v = self:getExpression(declaration.value)

    local _types = types_to_kinds[declaration.type]

    local err = nil

    -- print(_types)

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

    if expression_result == KINDS.LITERAL_FLOAT or expression_result == KINDS.LITERAL_INT then
        local max, min, var_max_size = self:getDeclarationVarSize(declaration)
        local value = literal_v
        if expression_result == KINDS.LITERAL_INT then
            print("VALUE", inspect(declaration))
            local num = tonumber(value)
            if num > max or num < min then
                self:error(string.format("Literal '%s' has a max and min of (%d : %d). value of literal is %s",
                    declaration.type, max, min, value))
            end
        else

        end
    end

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
