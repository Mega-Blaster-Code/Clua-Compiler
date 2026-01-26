-- tokens -> parser -> AST
local _M = {}

local inspect = require("inspect")
local file2io = require("file2io")
local color8 = require("color8")

local PRE_TOKENS, KEYWORDS

do
    local info = require("tokens")
    PRE_TOKENS, KEYWORDS = info[1], info[2]
end

local __signed = "__signed"

local __unsigned = "__unsigned"

local __types = {
    [PRE_TOKENS.INT] = true,
    [PRE_TOKENS.FLOAT] = true,
    [PRE_TOKENS.CHAR] = true,
    [PRE_TOKENS.DOUBLE] = true,
    [PRE_TOKENS.BOOL] = true,
    [PRE_TOKENS.VOID] = true,
    [PRE_TOKENS.NAME] = true -- structs
}

local __builtin_types = {
    [PRE_TOKENS.INT] = true,
    [PRE_TOKENS.FLOAT] = true,
    [PRE_TOKENS.CHAR] = true,
    [PRE_TOKENS.DOUBLE] = true,
    [PRE_TOKENS.BOOL] = true,
    [PRE_TOKENS.VOID] = true,
}

local __modifiers = {
    [PRE_TOKENS.CONST] = true,
    [PRE_TOKENS.VOLATILE] = true,
    [PRE_TOKENS.SIGNED] = true,
    [PRE_TOKENS.UNSIGNED] = true,
    [PRE_TOKENS.OPEN_BRACKETS] = true,
    [PRE_TOKENS.CLOSE_BRACKETS] = true,
    [PRE_TOKENS.ASTERISK] = true,
    [PRE_TOKENS.LONG] = true,
    [PRE_TOKENS.SHORT] = true
}

local __qualifiers = {
    [PRE_TOKENS.LONG] = true,
    [PRE_TOKENS.SHORT] = true
}

local __types_and_modifiers = {
    [PRE_TOKENS.INT] = true,
    [PRE_TOKENS.FLOAT] = true,
    [PRE_TOKENS.CHAR] = true,
    [PRE_TOKENS.DOUBLE] = true,
    [PRE_TOKENS.BOOL] = true,
    [PRE_TOKENS.VOID] = true,
    [PRE_TOKENS.NAME] = true,
    [PRE_TOKENS.CONST] = true,
    [PRE_TOKENS.VOLATILE] = true,
    [PRE_TOKENS.SIGNED] = true,
    [PRE_TOKENS.UNSIGNED] = true,
    [PRE_TOKENS.OPEN_BRACKETS] = true,
    [PRE_TOKENS.CLOSE_BRACKETS] = true,
    [PRE_TOKENS.ASTERISK] = true
}

local __numbers = {
    [PRE_TOKENS.NUMBER_INT] = true,
    [PRE_TOKENS.NUMBER_FLOAT] = true
}

local __math_level_1 = {
    [PRE_TOKENS.OR] = true
}

local __math_level_2 = {
    [PRE_TOKENS.AND] = true
}

local __math_level_3 = {
    [PRE_TOKENS.EQUAL_COMPARISON] = true,
    [PRE_TOKENS.GREATER_OR_EQUAL] = true,
    [PRE_TOKENS.GREATER] = true,
    [PRE_TOKENS.LOWER_OR_EQUAL] = true,
    [PRE_TOKENS.LOWER] = true,
    [PRE_TOKENS.DIFFERENT] = true
}

local __math_level_4 = {
    [PRE_TOKENS.PLUS] = true,
    [PRE_TOKENS.MINUS] = true
}

local __math_level_5 = {
    [PRE_TOKENS.DIVIDE] = true,
    [PRE_TOKENS.ASTERISK] = true,
    [PRE_TOKENS.MODULE] = true
}

local __math_unary = {
    [PRE_TOKENS.MINUS] = true,
    [PRE_TOKENS.NOT] = true
}

local __math_signs_level = {
    ["+"] = 1,
    ["-"] = 1,
    ["*"] = 2,
    ["/"] = 2,
    ["%"] = 2
}

local AST_SPEC, KINDS

do
    local info = require("ASTkinds")
    AST_SPEC, KINDS = info[1], info[2]
end

local parser = {}
parser.__index = parser

function _M.new(file_path, ARGUMENTS, tokens)
    local self = setmetatable({}, parser)
    self.file_path = file_path
	self.ARGUMENTS = ARGUMENTS

	self.replacements = {}

	--print(inspect(tokens))

    self.line = 1
    self.column = 1

    self.last_token_index = 1

    self.tokens = tokens
	
    self.AST = {}
    self.pos = 1

    self.buffer = {
        kind = KINDS.PROGRAM,
        body = {}
    }

    self.scopes = {self.buffer.body}
    return self
end

function parser:validate_name(name)
	local error = string.format("the name '%s' is a keyword and can't be used for names", name)
	if name == "sizeof" then
		self:error(error)
	end
	for k, v in pairs(KEYWORDS) do
		if k == name then
			self:error(error)
		end
	end
	return name
end

function parser:error(msg, raise)
    local line = self.line
    local column = self.column

	local left_off = 10
	local right_off = 10

    local tokens = {}
    do -- local variables
        local i = 0
        while i < left_off do
            local left = self.tokens[-i + self.last_token_index]
            if left then
				if left.token == PRE_TOKENS.NEW_LINE then
					break
				end
                table.insert(tokens, {
                    index = -i,
                    token = left
                })
            end
            i = i + 1
        end
        i = 1
        while i < right_off do
            local right = self.tokens[i + self.last_token_index]
            if right then
				if right.token == PRE_TOKENS.NEW_LINE then
					break
				end
                table.insert(tokens, {
                    index = i,
                    token = right
                })
            end
            i = i + 1
        end

        table.sort(tokens, function(a, b)
            return a.index < b.index
        end)
    end

	local message = {}

    message[#message + 1] = (string.format("PARSER ['%s'] line %s column %s\n", self.file_path, line, column))
    message[#message + 1] = (msg)
    message[#message + 1] = ("\n\n")

    for i, token in ipairs(tokens) do
        message[#message + 1] = (token.token.buf:gsub("%c", " "))
        if #token.token.buf > 0 then
            message[#message + 1] = (" ")
        end
    end
    message[#message + 1] = ("\n")

    color8.error = true
    message[#message + 1] = color8.sfcolor(0, 128, 128)
    for i, token in ipairs(tokens) do
        if #token.token.buf > 0 then
            for j = 1, #token.token.buf do
				if token.index == 0 then
					message[#message + 1] = color8.sfcolor(255, 0, 0)
                	message[#message + 1] = ("^")
				else
					message[#message + 1] = color8.sfcolor(0, 128, 128)
					message[#message + 1] = ("-")
				end
			end
			message[#message + 1] = color8.sfcolor(0, 128, 128)
			if i ~= #tokens then
				message[#message + 1] = ("-")
			end

        end
    end
    message[#message + 1] = color8.sfcolor(200, 200, 200)
	message[#message + 1] = ("\n")

	message = table.concat(message)

	self.ARGUMENTS:ERROR(message)
end

function parser:warn(msg, raise)
    local line = self.line
    local column = self.column

	local left_off = 10
	local right_off = 10

    local tokens = {}
    do -- local variables
        local i = 0
        while i < left_off do
            local left = self.tokens[-i + self.last_token_index]
            if left then
				if left.token == PRE_TOKENS.NEW_LINE then
					break
				end
                table.insert(tokens, {
                    index = -i,
                    token = left
                })
            end
            i = i + 1
        end
        i = 1
        while i < right_off do
            local right = self.tokens[i + self.last_token_index]
            if right then
				if right.token == PRE_TOKENS.NEW_LINE then
					break
				end
                table.insert(tokens, {
                    index = i,
                    token = right
                })
            end
            i = i + 1
        end

        table.sort(tokens, function(a, b)
            return a.index < b.index
        end)
    end

	local message = {}
	
    message[#message + 1] = (string.format("PARSER ['%s'] line %s column %s\n", self.file_path, line, column))
    message[#message + 1] = (msg)
    message[#message + 1] = ("\n\n")

    for i, token in ipairs(tokens) do
        message[#message + 1] = (token.token.buf:gsub("%c", " "))
        if #token.token.buf > 0 then
            message[#message + 1] = (" ")
        end
    end
    message[#message + 1] = ("\n")

    color8.error = true
    message[#message + 1] = color8.sfcolor(0, 128, 128)
    for i, token in ipairs(tokens) do
        if #token.token.buf > 0 then
            for j = 1, #token.token.buf do
				if token.index == 0 then
					message[#message + 1] = color8.sfcolor(255, 190, 0)
                	message[#message + 1] = ("^")
				else
					message[#message + 1] = color8.sfcolor(0, 128, 128)
					message[#message + 1] = ("-")
				end
			end
			message[#message + 1] = color8.sfcolor(0, 128, 128)
			if i ~= #tokens then
				message[#message + 1] = ("-")
			end

        end
    end
    message[#message + 1] = color8.sfcolor(200, 200, 200)
	message[#message + 1] = ("\n")

	message = table.concat(message)

	self.ARGUMENTS:WARN(message)
end

function parser:notification(msg)
    local line = self.line
    local column = self.column

	local left_off = 10
	local right_off = 10

    local tokens = {}
    do -- local variables
        local i = 0
        while i < left_off do
            local left = self.tokens[-i + self.last_token_index]
            if left then
				if left.token == PRE_TOKENS.NEW_LINE then
					break
				end
                table.insert(tokens, {
                    index = -i,
                    token = left
                })
            end
            i = i + 1
        end
        i = 1
        while i < right_off do
            local right = self.tokens[i + self.last_token_index]
            if right then
				if right.token == PRE_TOKENS.NEW_LINE then
					break
				end
                table.insert(tokens, {
                    index = i,
                    token = right
                })
            end
            i = i + 1
        end

        table.sort(tokens, function(a, b)
            return a.index < b.index
        end)
    end

	local message = {}

	
    message[#message + 1] = (string.format("PARSER ['%s'] line %s column %s\n", self.file_path, line, column))
    message[#message + 1] = (msg)
    message[#message + 1] = ("\n\n")

    for i, token in ipairs(tokens) do
        message[#message + 1] = (token.token.buf:gsub("%c", " "))
        if #token.token.buf > 0 then
            message[#message + 1] = (" ")
        end
    end
    message[#message + 1] = ("\n")

    color8.error = true
    message[#message + 1] = color8.sfcolor(0, 128, 128)
    for i, token in ipairs(tokens) do
        if #token.token.buf > 0 then
            for j = 1, #token.token.buf do
				if token.index == 0 then
					message[#message + 1] = color8.sfcolor(90, 90, 90)
                	message[#message + 1] = ("^")
				else
					message[#message + 1] = color8.sfcolor(0, 128, 128)
					message[#message + 1] = ("-")
				end
			end
			message[#message + 1] = color8.sfcolor(0, 128, 128)
			if i ~= #tokens then
				message[#message + 1] = ("-")
			end

        end
    end
    message[#message + 1] = color8.sfcolor(200, 200, 200)
	message[#message + 1] = ("\n")

	local message = table.concat(message)

	self.ARGUMENTS:INFO(message)
end

function parser:CEexpect(pretoken, length)
    local p = self:peek(length)
    if not p or p.token ~= pretoken then
        self:error(string.format("expected ['%s'] but got ['%s']", pretoken, tostring((p or {}).token)))
    end
    return self:consume()
end

function parser:TCEexpect(tbl, length)
    local p = self:peek(length)
    if not p or not tbl[p.token] then
        self:error(string.format("expected [custom table] but got ['%s']", tostring((p or {}).token)))
    end
    return self:consume()
end

function parser:token_in_class(token, tbl)
    if not token then
        self:error("Expected token but received ['nil']")
    end
    if not tbl then
        self:error("Compiler error. Expected custom table but received ['nil']")
    end
    return tbl[token.token]
end

function parser:Econsume()
    if not self:peek() then
        self:error("Incomplete Consume")
    end

    return self:consume()
end

function parser:skip_newlines()
    while true do
        local t = self.tokens[self.pos]
        if not t or (t.token ~= PRE_TOKENS.NEW_LINE and t.token ~= PRE_TOKENS.TAB) then
            break
        end
        self.pos = self.pos + 1
		self.last_token_index = self.pos
    end
end

function parser:consume()
	self:skip_newlines()
    local t = self.tokens[self.pos]
    self.pos = self.pos + 1
	self.last_token_index = self.pos
    return t
end

function parser:peek(length)
	self:skip_newlines()
    length = length or 0
    local t = self.tokens[self.pos + length]
    if t then
        self.line = t.line
        self.column = t.column
    end
    return t
end

function parser:push_back(content)
    local local_scope = self.scopes[#self.scopes]
    local_scope[#local_scope + 1] = content
end

function parser:new_scope(body_pointer)
    self.scopes[#self.scopes + 1] = body_pointer
end

function parser:end_scope()
    if #self.scopes < 1 then
        self:error("Can't close global scope")
    end
    table.remove(self.scopes, #self.scopes)
end

function parser:Eexpect(pretoken, length)
    local p = self:peek(length)
    if not p or p.token ~= pretoken then
        self:error(string.format("expected ['%s'] but got ['%s']", pretoken, tostring((p or {}).token)))
    end
    return true
end

function parser:expect(pretoken, length)
    local p = self:peek(length)
    if not p then
        return false
    end
    if p.token ~= pretoken then
        return false
    end
    return true
end

function parser:Texpect(tbl, length)
    local p = self:peek(length)
    if not p then
        return false
    end
    if not tbl[p.token] then
        return false
    end
    return p
end

function parser:Cexpect(pretoken, length)
    if not self:peek(length) then
        return false
    end
    if self:peek().token ~= pretoken then
        return false
    end
    local t = self:consume()
    return t
end

function parser:parse_primary(is_pointer)
    local tok = self:peek()
    if not tok then
        self:error("Incomplete expression")
    end

    if tok.token == PRE_TOKENS.OPEN_PARENTHESES then
        self:consume()
        local expr = self:parse_expression()
        self:Eexpect(PRE_TOKENS.CLOSE_PARENTHESES)
        self:consume()
        return expr
    end

	if tok.token == PRE_TOKENS.OPEN_BRACES then
        return self:parse_struct_init()
    end

    if tok.token == PRE_TOKENS.NUMBER_INT or tok.token == PRE_TOKENS.NUMBER_FLOAT then
        self:consume()
        return {
            kind = KINDS.LITERAL,
            value = tonumber(tok.buf)
        }
    end

    if tok.token == PRE_TOKENS.STRING_LITERAL then
        self:consume()
        return {
            kind = KINDS.STRING_LITERAL,
            value = tok.buf
        }
    end

    if tok.token == PRE_TOKENS.CHAR_LITERAL then
        self:consume()
        return {
            kind = KINDS.CHAR_LITERAL,
            value = tok.buf
        }
    end

    if tok.token == PRE_TOKENS.TRUE or tok.token == PRE_TOKENS.FALSE then
        self:consume()
        return {
            kind = KINDS.LITERAL_BOOL,
            value = tok.buf == "true"
        }
    end

    if tok.token == PRE_TOKENS.NAME then
        if self:expect(PRE_TOKENS.OPEN_PARENTHESES, 1) then
            return self:parse_call()
        end

        local node = {
            kind = KINDS.VAR_REF,
            name = self:validate_name(tok.buf)
        }

        self:consume()

        return node
    end

    self:error(string.format("Invalid primary expression ['%s'] ['%s']", tok.token, tok.buf))
end

function parser:parse_postfix()
    local base = self:parse_primary()
	
	local local_base = base

    while true do
        if self:expect(PRE_TOKENS.OPEN_BRACKETS) then
            self:consume()
            local index = self:parse_expression()
            self:CEexpect(PRE_TOKENS.CLOSE_BRACKETS)
            local_base.node = {
                kind = KINDS.INDEX_FIELD_ACCESS,
                index = index
            }

        elseif self:expect(PRE_TOKENS.DOT) then
            self:consume()
            local name = self:validate_name(self:CEexpect(PRE_TOKENS.NAME).buf)
			
            local_base.node = {
                kind = KINDS.FIELD_ACCESS,
                name = name
            }

        elseif self:expect(PRE_TOKENS.POINTER) then
            self:consume()
            local name = self:validate_name(self:CEexpect(PRE_TOKENS.NAME).buf)
            local_base.node = {
                kind = KINDS.POINTER_FIELD_ACCESS,
                name = name
            }

        else
            break
        end
		base.kind = KINDS.VAR_REF_WITH_FIELDS
		local_base = local_base.node
    end

    return base
end

function parser:parse_unary()
    if self:Texpect(__math_unary) then
        local op = self:consume()
        return {
            kind = KINDS.UNARY_EXPRESSION,
            op = op.buf,
            expr = self:parse_unary()
        }
    end

    if self:expect(PRE_TOKENS.ASTERISK) then
        local op = self:consume()
        return {
            kind = KINDS.POINTER_DEREFERENCE,
            op = op.buf,
            expr = self:parse_unary()
        }
    end

    if self:expect(PRE_TOKENS.AMPERSAND) then
        local op = self:consume()
        return {
            kind = KINDS.ADDRESS_OF,
            op = op.buf,
            expr = self:parse_unary()
        }
    end

    return self:parse_postfix()
end

function parser:parse_mul()
    local left = self:parse_unary()

    while self:Texpect(__math_level_5) do
        local op = self:consume()
        left = {
            kind = KINDS.BINARY_EXPRESSION,
            op = op.buf,
            left = left,
            right = self:parse_unary()
        }
    end

    return left
end

function parser:parse_add()
    local left = self:parse_mul()

    while self:Texpect(__math_level_4) do
        local op = self:consume()
        left = {
            kind = KINDS.BINARY_EXPRESSION,
            op = op.buf,
            left = left,
            right = self:parse_mul()
        }
    end

    return left
end

function parser:parse_comparison()
    local left = self:parse_add()

    if self:Texpect(__math_level_3) then
        local op = self:consume()
        left = {
            kind = KINDS.BINARY_EXPRESSION,
            op = op.buf,
            left = left,
            right = self:parse_add()
        }
    end

    return left
end

function parser:parse_and()
    local left = self:parse_comparison()

    while self:Texpect(__math_level_2) do
        local op = self:consume()
        left = {
            kind = KINDS.BINARY_EXPRESSION,
            op = op.buf,
            left = left,
            right = self:parse_comparison()
        }
    end

    return left
end

function parser:parse_or()
    local left = self:parse_and()

    while self:Texpect(__math_level_1) do
        local op = self:consume()
        left = {
            kind = KINDS.BINARY_EXPRESSION,
            op = op.buf,
            left = left,
            right = self:parse_and()
        }
    end

    return left
end

function parser:parse_expression()
    if self:expect(PRE_TOKENS.OPEN_BRACKETS) then
        self:consume()
        local values_of_array = {}
        while true do
            local expr = self:parse_expression()
            values_of_array[#values_of_array + 1] = expr
            if not self:expect(PRE_TOKENS.COMMA) then
                break
            end
            self:consume()
        end
        self:Eexpect(PRE_TOKENS.CLOSE_BRACKETS)
        self:consume()
        return {
            kind = KINDS.ARRAY,
            value = values_of_array
        }
    end
    return self:parse_or()
end

function parser:parse_call()
    local tok = self:consume() -- name
    local name = tok.buf

    self:consume() -- '('

    local args = {}

	if name == "sizeof" then
		if self:Texpect(__builtin_types) then
			local t = {
				kind = KINDS.SIZEOF,
				value = {
					kind = KINDS.RAW_TYPE,
					value = self:consume().buf
				}
			}
			self:CEexpect(PRE_TOKENS.CLOSE_PARENTHESES)
			return t
		end

		self:Eexpect(PRE_TOKENS.NAME)

		local t = {
			kind = KINDS.SIZEOF,
			value = {
				kind = KINDS.VAR_REF,
				value = self:validate_name(self:consume().buf)
			}
		}
		self:CEexpect(PRE_TOKENS.CLOSE_PARENTHESES)
		return t
	end

	name = self:validate_name(name)

    if not self:expect(PRE_TOKENS.CLOSE_PARENTHESES) then
        while true do
            table.insert(args, self:parse_expression())
            -- print(inspect(self:peek()))

            if not self:Cexpect(PRE_TOKENS.COMMA) then
                break
            end
        end
    end

    self:Eexpect(PRE_TOKENS.CLOSE_PARENTHESES)
    self:consume() -- ')'

    return {
        kind = KINDS.CALL_EXPRESSION,
        callee = name,
        args = args
    }
end

function parser:parse_function_declaration(name, type, modifiers, qualifiers)

    local args = {}

    self:Eexpect(PRE_TOKENS.OPEN_PARENTHESES)
    self:consume()

    if not self:peek() then
        self:error("Incomplete Function declaration")
    end

    while true do
        if self:expect(PRE_TOKENS.CLOSE_PARENTHESES) then
            break
        end

        local var = self:parse_variable_types()

        table.insert(args, {
            type = var.type,
            modifiers = var.modifiers
        })

        if var.is_function then
            self:error("Can't declare a function inside a function arguments")
        end

        self:Cexpect(PRE_TOKENS.COMMA)
    end

    self:Eexpect(PRE_TOKENS.CLOSE_PARENTHESES)

    self:consume() -- ')'

    return {
        kind = KINDS.FUNCTION_DECLARATION,
        callee = name,
        init_args = args,
        return_type = type,
        return_modifiers = modifiers,
        return_qualifiers = qualifiers,
        body = {}
    }
end

function parser:parse_struct_init()
    self:CEexpect(PRE_TOKENS.OPEN_BRACES)

    local values = {}

    while self:expect(PRE_TOKENS.DOT) do
        self:consume() -- '.'
        local name = self:validate_name(self:CEexpect(PRE_TOKENS.NAME).buf)
        self:CEexpect(PRE_TOKENS.EQUAL_ASSIGNING)
        local value
        if self:expect(PRE_TOKENS.OPEN_BRACES) then
            value = self:parse_struct_init()
        else
            value = self:parse_expression()
        end
        table.insert(values, {
            kind = KINDS.STRUCT_INIT_VAR_DECLARATION,
            value = value,
            name = name
        })

        if not self:Cexpect(PRE_TOKENS.COMMA) then
            break
        end
    end

    if #values == 0 then
        self:error("Struct can't be empty")
    end

    self:CEexpect(PRE_TOKENS.CLOSE_BRACES)

    return {
        kind = KINDS.STRUCT_INIT,
        values = values
    }
end

function parser:parse_assignment()
    local lvalue = self:parse_expression()

    self:CEexpect(PRE_TOKENS.EQUAL_ASSIGNING)

    local value = self:parse_expression()

    return {
        kind = KINDS.ASSIGNMENT,
        target = lvalue,
        value = value
    }
end

function parser:parse_variable_types()
    local type = self:Texpect(__types)
    if type then
        self:consume()
        type = type.buf
    end

    local modifiers = {}
    local qualifiers = {}

    local long_count = 0
    local is_short = false

    local sign = nil

    while self:Texpect(__modifiers) do
        local mod = self:consume()

        if mod.token == PRE_TOKENS.ASTERISK then
            table.insert(modifiers, {
                kind = KINDS.POINTER_MODIFIER
            })

        elseif mod.token == PRE_TOKENS.OPEN_BRACKETS then
            local size = 0
            if not self:expect(PRE_TOKENS.CLOSE_BRACKETS) then
                size = self:parse_expression()
            end
            self:CEexpect(PRE_TOKENS.CLOSE_BRACKETS)

            table.insert(modifiers, {
                kind = KINDS.ARRAY_MODIFIER,
                size = size
            })

        elseif self:token_in_class(mod, {
            [PRE_TOKENS.SIGNED] = true,
            [PRE_TOKENS.UNSIGNED] = true
        }) then
            if sign then
                self:error("Variable can't be 'signed' and 'unsigned' ate the same time")
            end
            if mod.token == PRE_TOKENS.UNSIGNED then
                sign = __unsigned
            end

            sign = __signed

        elseif self:token_in_class(mod, __qualifiers) then
            if #modifiers > 0 then
                self:error("Qualifiers need to be along the type and can only be aplyed to a type")
            end

            if mod.token == PRE_TOKENS.LONG then
                if long_count >= 2 then
                    self:error("Variable can't be 'long long long'")
                end
                long_count = long_count + 1
            elseif mod.token == PRE_TOKENS.SHORT then
                if is_short then
                    self:error("Variable can't be 'short short'")
                end
                is_short = true
            end

            table.insert(qualifiers, {
                kind = KINDS.QUALIFICATOR,
                value = mod.buf
            })
        else

            table.insert(modifiers, {
                kind = KINDS.MODIFIER,
                value = mod.buf
            })
        end
    end

    if is_short and long_count > 0 then
        self:error("Variable can't be 'short' and 'long' at the same time")
    end

    if self:expect(PRE_TOKENS.FUNCTION) then
        self:consume()
        local name = self:validate_name(self:CEexpect(PRE_TOKENS.NAME).buf)
        return self:parse_function_declaration(name, type, modifiers, qualifiers), true
    end

    local name = self:validate_name(self:CEexpect(PRE_TOKENS.NAME).buf)

    -- declaração sem valor
    if not self:expect(PRE_TOKENS.EQUAL_ASSIGNING) then
        return {
            kind = KINDS.NULL_VAR_DECLARATION,
            name = name,
            type = type,
            qualifiers = qualifiers,
            modifiers = modifiers
        }
    end

    -- declaração com valor
    self:consume()
    local value = self:parse_expression()

    return {
        kind = KINDS.VAR_DECLARATION,
        name = name,
        type = type,
        modifiers = modifiers,
        qualifiers = qualifiers,
        value = value
    }
end

function parser:parse_if()
    self:consume() -- "if"
    self:CEexpect(PRE_TOKENS.OPEN_PARENTHESES) -- "("

    local contition = self:parse_expression()

    self:CEexpect(PRE_TOKENS.CLOSE_PARENTHESES) -- ")"

    self:CEexpect(PRE_TOKENS.THEN) -- ")"

    local body = {}

    return {
        kind = KINDS.IF,
        condition = contition,
        body = {}
    }
end

function parser:parse_while()
    self:consume() -- "while"
    self:CEexpect(PRE_TOKENS.OPEN_PARENTHESES) -- "("

    local contition = self:parse_expression()

    self:CEexpect(PRE_TOKENS.CLOSE_PARENTHESES) -- ")"

    self:CEexpect(PRE_TOKENS.DO) -- ")"

    local body = {}

    return {
        kind = KINDS.WHILE,
        condition = contition,
        body = {}
    }
end

function parser:parse_for()
    self:consume() -- "for"
    self:CEexpect(PRE_TOKENS.OPEN_PARENTHESES) -- "("

    local var = self:parse_variable_types()

    self:CEexpect(PRE_TOKENS.SEMICOLON) -- ";"

    local condition = self:parse_expression()

    self:CEexpect(PRE_TOKENS.SEMICOLON) -- ";"

    local var1 = self:parse_assignment()

    self:CEexpect(PRE_TOKENS.CLOSE_PARENTHESES) -- ")"

    self:CEexpect(PRE_TOKENS.DO) -- ")"

    local body = {}

    return {
        kind = KINDS.FOR,
        condition = condition,
        init = var,
        step = var1,
        body = {}
    }
end

function parser:parse_struct()
    self:consume() -- "struct"

    local name = self:validate_name(self:CEexpect(PRE_TOKENS.NAME).buf)

    self:CEexpect(PRE_TOKENS.OPEN_BRACES)

    if self:expect(PRE_TOKENS.CLOSE_BRACES) then
        self:error("Struct can't be empty")
    end

    local variables = {}

    while self:Texpect(__types_and_modifiers) do
        local decla_var = self:parse_variable_types()
        if decla_var.kind ~= KINDS.NULL_VAR_DECLARATION and decla_var.kind ~= KINDS.CUSTOM_NULL_VAR_DECLARATION then
            self:error("Invalid struct declaration sintax")
        end

        if decla_var.kind == KINDS.NULL_VAR_DECLARATION then
            decla_var.kind = KINDS.STRUCT_VAR_DECLARATION
        else
            self:error("some declaration of variables in struct is wrong (i think this error is impossible to triger)")
        end

        table.insert(variables, decla_var)
        self:CEexpect(PRE_TOKENS.SEMICOLON)
    end

    -- print(inspect(variables))

    self:CEexpect(PRE_TOKENS.CLOSE_BRACES)

    return {
        kind = KINDS.STRUCT_DECLARATION,
        variables = variables,
        name = name
    }
end

function parser:parse_enum()
    self:consume() -- "enum"

    local name = self:validate_name(self:CEexpect(PRE_TOKENS.NAME).buf)

    self:CEexpect(PRE_TOKENS.OPEN_BRACES)

    if self:expect(PRE_TOKENS.CLOSE_BRACES) then
        self:error("Enums can't be empty")
    end

    local variables = {}

    while not self:expect(PRE_TOKENS.CLOSE_BRACES) do

		local name = self:validate_name(self:CEexpect(PRE_TOKENS.NAME).buf)

        variables[#variables + 1] = name
        self:CEexpect(PRE_TOKENS.COMMA)
    end

    --print(inspect(variables))

    self:CEexpect(PRE_TOKENS.CLOSE_BRACES)

    return {
        kind = KINDS.ENUM_DECLARATION,
        variables = variables,
        name = name
    }
end

function parser:parse_return()
    self:consume() -- "return"

    local expression = self:parse_expression()

    return {
        kind = KINDS.RETURN,
        value = expression
    }
end

function parser:parse_statement()
    if self:expect(PRE_TOKENS.NAME) or self:expect(PRE_TOKENS.ASTERISK) or self:expect(PRE_TOKENS.OPEN_PARENTHESES) then
        if self:expect(PRE_TOKENS.NAME) and self:expect(PRE_TOKENS.OPEN_PARENTHESES, 1) then -- function call 'test();'
            self:push_back(self:parse_call())
            if self.use_semicolan then
                self:CEexpect(PRE_TOKENS.SEMICOLON)
            end -- ";"
            return
        end

        if not (self:expect(PRE_TOKENS.NAME) and self:expect(PRE_TOKENS.NAME, 1)) then
            self:push_back(self:parse_assignment())
            if self.use_semicolan then
                self:CEexpect(PRE_TOKENS.SEMICOLON)
            end -- ";"
            return
        end
    end

    if self:Texpect(__types) then
        local info, ignore_semicolon = self:parse_variable_types()
        -- print(inspect(info))
        self:push_back(info)
        if not ignore_semicolon then
            if self.use_semicolan then
                self:CEexpect(PRE_TOKENS.SEMICOLON)
            end -- ";"
            return
        end
        self:new_scope(info.body)
        return
    end

    if self:expect(PRE_TOKENS.DO) then -- raw do 'do ... end'
        local body = {}
        self:push_back({
            kind = KINDS.RAW_DO,
            body = body
        })
        self:consume()
        self:new_scope(body)
        return
    end

    if self:expect(PRE_TOKENS.WHILE) then -- while 'while (condition) do ... end'
        local _while = self:parse_while()
        self:push_back(_while)
        self:new_scope(_while.body)
        return
    end

    if self:expect(PRE_TOKENS.IF) then -- if 'if (condition) then ... end'
        local _if = self:parse_if()
        self:push_back(_if)
        self:new_scope(_if.body)
        return
    end

    if self:expect(PRE_TOKENS.FOR) then -- for 'for (definition; condition; definition) do .. end'
        local _for = self:parse_for()
        self:push_back(_for)
        self:new_scope(_for.body)
        return
    end

	if self:expect(PRE_TOKENS.BREAK) then
		self:consume()
		self:push_back({
			kind = KINDS.BREAK,
		})
		return
	end

    if self:expect(PRE_TOKENS.END) then -- end 'end'
        self:end_scope()
        self:consume()
        return
    end

	self:warn("terst")

    if self:expect(PRE_TOKENS.RETURN) then -- return 'return expression'
        self:push_back(self:parse_return())
        self:consume()
        return
    end

    if self:expect(PRE_TOKENS.STRUCT) then -- struct 'struct name{type name; type name1;};'
        self:push_back(self:parse_struct())
        if self.use_semicolan then
            self:CEexpect(PRE_TOKENS.SEMICOLON)
        end -- ";"
        return
    end

	if self:expect(PRE_TOKENS.ENUM) then -- enum 'enum name {name1, name2, name3};'
        self:push_back(self:parse_enum())
        if self.use_semicolan then
            self:CEexpect(PRE_TOKENS.SEMICOLON)
        end -- ";"
        return
    end

    if self:expect(PRE_TOKENS.LINE_COMMENT) then
        self:consume()
        return
    end

    if self:expect(PRE_TOKENS.SEMICOLON) then
        self:consume()
        return
    end

    self:error(string.format("Invalid statement ['%s']", self:peek().token))
end

function parser:start(use_semicolan)
    self.use_semicolan = use_semicolan
    while self:peek() do
        self:parse_statement()
    end

    self:end_scope()

    if #self.scopes > 0 then
        self:error("Scope was not closed")
    end

    --print(inspect(self.buffer))
	return self.buffer
end

return _M
