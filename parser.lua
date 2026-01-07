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

local __types = {
    [PRE_TOKENS.INT] = true,
    [PRE_TOKENS.FLOAT] = true,
    [PRE_TOKENS.CHAR] = true,
    [PRE_TOKENS.DOUBLE] = true,
    [PRE_TOKENS.BOOL] = true,
    [PRE_TOKENS.VOID] = true,
    [PRE_TOKENS.NAME] = true -- structs
}

local __modifiers = {
    [PRE_TOKENS.CONST] = true,
    [PRE_TOKENS.VOLATILE] = true,
    [PRE_TOKENS.SIGNED] = true,
    [PRE_TOKENS.UNSIGNED] = true,
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

function _M.new(tokens)
    local self = setmetatable({}, parser)

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

function parser:CEexpect(pretoken, length)
    local p = self:peek(length)
    if not p or p.token ~= pretoken then
        error(string.format("Error expected ['%s'] but got ['%s']", pretoken, tostring((p or {}).token)))
    end
    return self:consume()
end

function parser:Econsume()
    if not self:peek() then
        error("Inconplete Consume")
    end

    return self:consume()
end

function parser:consume()
    local t = self.tokens[self.pos]
    self.pos = self.pos + 1
    return t
end

function parser:peek(length)
    length = length or 0
    local t = self.tokens[self.pos + length]
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
        error("Can't close global scope")
    end
    table.remove(self.scopes, #self.scopes)
end

function parser:Eexpect(pretoken, length)
    local p = self:peek(length)
    if not p or p.token ~= pretoken then
        error(string.format("Error expected ['%s'] but got ['%s']", pretoken, tostring((p or {}).token)))
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
    return true
end

function parser:Cexpect(pretoken, length)
    if not self:peek(length) then
        return false
    end
    if self:peek().token ~= pretoken then
        return false
    end
    local t = self:consume()
    return true
end

function parser:parse_primary(is_pointer)
    local tok = self:peek()
    if not tok then
        error("Incomplete expression")
    end

    if tok.token == PRE_TOKENS.OPEN_PARENTHESES then
        self:consume()
        local expr = self:parse_expression()
        self:Eexpect(PRE_TOKENS.CLOSE_PARENTHESES)
        self:consume()
        return expr
    end

    if tok.token == PRE_TOKENS.NUMBER_INT or tok.token == PRE_TOKENS.NUMBER_FLOAT then
        self:consume()
        return {
            kind = KINDS.LITERAL,
            value = tonumber(tok.buf)
        }
    end

    if tok.token == PRE_TOKENS.STRING then
        self:consume()
        return {
            kind = KINDS.STRING_LITERAL,
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

		self:consume()

        local node = {
            kind = KINDS.VAR_REF,
            name = tok.buf
		}

		if self:expect(PRE_TOKENS.DOT) then
			while self:expect(PRE_TOKENS.DOT) do
				self:consume() -- '.'
				local field = self:CEexpect(PRE_TOKENS.NAME)

				node = {
					kind = KINDS.FIELD_ACCESS,
					base = node,
					field = field.buf
				}
			end
			return node
		end

        return node
    end

    error(string.format("Invalid primary expression ['%s'] ['%s']", tok.token, tok.buf))
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

    return self:parse_primary()
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

    while self:Texpect(__math_level_3) do
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
    return self:parse_or()
end

function parser:parse_call()
    local tok = self:consume() -- name
    local name = tok.buf

    self:consume() -- '('

    local args = {}

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

function parser:parse_function_declaration()
    local type_token = self:consume() -- type

    self:consume() -- function

    local name_token = self:consume() -- name

    local name = name_token.buf

    local args = {}

    if self:Eexpect(PRE_TOKENS.OPEN_PARENTHESES) then
        self:consume()
        if not self:peek() then
            error("Incomplete Function declaration")
        end
        while true do
            if self:expect(PRE_TOKENS.CLOSE_PARENTHESES) then
                break
            end

            if not self:Texpect(__types) then
                error(string.format("Expected a 'type' but received ['%s']", self:peek().token))
            end

            local type = self:Econsume().buf
            local name = self:Econsume().buf

            table.insert(args, {
                name = name,
                type = type
            })

            if not self:Cexpect(PRE_TOKENS.COMMA) then
                break
            end
        end
    end

    self:Eexpect(PRE_TOKENS.CLOSE_PARENTHESES)

    self:consume() -- ')'

    return {
        kind = KINDS.FUNCTION_DECLARATION,
        callee = name,
        init_args = args,
        body = {}
    }
end


function parser:parse_var_definition()
    if not self:peek() or not self:peek(1) then
        error("Incomplete var definition")
    end

	local var = {
		kind = KINDS.NULL_VAR_REDEFINITION,
		type = nil,
		modifiers = {},
		value = {},
	}

	if self:Texpect(__types_and_modifiers) then
		var.kind = KINDS.VAR_DECLARATION
		if self:Texpect(__types_and_modifiers) then
			while self:Texpect(__types_and_modifiers) do
				if self:Texpect(__modifiers) then
					table.insert(var.modifiers, {
						kind = KINDS.MODIFIER,
						value = self:consume().buf
					})
				else
					if not self:Texpect(__types_and_modifiers, 1) then
						break
					end

					if var.type then
						error("Variable has two types")
					end

					if self:expect(PRE_TOKENS.NAME) then
						var.kind = KINDS.CUSTOM_VAR_DECLARATION
					end

					var.type = self:consume().buf
				end
			end
		end

		if not var.type then
			if #var.modifiers > 0 then
				error("Error variable don't have a type")
			end

			var.kind = KINDS.VAR_REDEFINITION
		end

		local name = self:CEexpect(PRE_TOKENS.NAME)
		var.name = name.buf

		if not self:expect(PRE_TOKENS.EQUAL_ASSIGNING) then
			if var.kind == KINDS.CUSTOM_VAR_DECLARATION then
				var.kind = KINDS.CUSTOM_NULL_VAR_DECLARATION
			else
				var.kind = KINDS.NULL_VAR_DECLARATION
			end
			var.value = nil
			
			return var
		end

		self:CEexpect(PRE_TOKENS.EQUAL_ASSIGNING)
		local expression = self:parse_expression()

		var.value = expression

		return var
	end


    error(string.format("Invalid var defenition ['%s']", self:peek().token))
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

    local var = self:parse_var_definition()

    self:CEexpect(PRE_TOKENS.SEMICOLON) -- ";"

    local condition = self:parse_expression()

    self:CEexpect(PRE_TOKENS.SEMICOLON) -- ";"

    local var1 = self:parse_var_definition()

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

	local name = self:CEexpect(PRE_TOKENS.NAME).buf

	self:CEexpect(PRE_TOKENS.OPEN_BRACES)

	--local variables = self:parse_va

	self:CEexpect(PRE_TOKENS.CLOSE_BRACES)
    

    return {
        kind = KINDS.STRUCT_DECLARATION,
		variables = {},
		name = name,
    }
end

function parser:parse_statement()
    if self:Texpect(__types_and_modifiers)then
		
        if self:expect(PRE_TOKENS.FUNCTION, 1) then -- function declaration 'void function test() .. end'
            local func = self:parse_function_declaration()
            self:push_back(func)

            self:new_scope(func.body)
            return
        end

        -- var declaration 'int x = 10;'
		self:push_back(self:parse_var_definition())
		self:CEexpect(PRE_TOKENS.SEMICOLON) -- ";"
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

    if self:expect(PRE_TOKENS.NAME) then
        if self:expect(PRE_TOKENS.OPEN_PARENTHESES, 1) then -- function call 'test();'
            self:push_back(self:parse_call())
            self:CEexpect(PRE_TOKENS.SEMICOLON) -- ";"
            return
        end

        if self:expect(PRE_TOKENS.EQUAL_ASSIGNING, 1) then -- var redefinition 'x = 6;'
            self:push_back(self:parse_var_definition())
            self:CEexpect(PRE_TOKENS.SEMICOLON) -- ";"
            return
        end
    end

    if self:expect(PRE_TOKENS.END) then -- end 'end'
        self:end_scope()
        self:consume()
        return
    end

	if self:expect(PRE_TOKENS.STRUCT) then -- end 'end'
		self:push_back(self:parse_struct())
        self:CEexpect(PRE_TOKENS.SEMICOLON) -- ";"
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

    error(string.format("Invalid statement ['%s']", self:peek().token))
end

function _M.parse(__t)
    local parser = _M.new(__t)
    while parser:peek() do
        parser:parse_statement()
    end

    parser:end_scope()

    if #parser.scopes > 0 then
        error("Scope was not closed")
    end

    print(inspect(parser.buffer))

    print(inspect(parser.scopes))
end

return _M
