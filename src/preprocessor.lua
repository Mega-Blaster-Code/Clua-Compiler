-- preprocessor directive
local _M = {}

local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")

local lexer = require("lexer")

local processor = {}
processor.__index = processor

local PRE_TOKENS, KEYWORDS

do
    local info = require("tokens")
    PRE_TOKENS, KEYWORDS = info[1], info[2]
end

local macros = {
    define = {
        tokens = {},
        args = {}
    },
    undef = {
        tokens = {},
        args = {}
    },
    require = {
        tokens = {},
        args = {}
    },
    prerequire = {
        tokens = {},
        args = {}
    }, -- TODO
    ifndef = {
        tokens = {},
        args = {}
    },
    ifdef = {
        tokens = {},
        args = {}
    },
    ["if"] = {
        tokens = {},
        args = {}
    },
    ["else"] = {
        tokens = {},
        args = {}
    },
    ["elseif"] = {
        tokens = {},
        args = {}
    },
    endif = {
        tokens = {},
        args = {}
    }
}

local KINDS = {
    INDEX = "__INDEX",
    TOKEN = "__TOKEN"
}

local directives = {}

local function capture_expr_at(self, pos)
    local expr = {}
    local depth = 0
    local p = pos

    while true do
        local t = self:peek_at(p)
        if not t then
            break
        end

        if t.token == PRE_TOKENS.OPEN_PARENTHESES then
            depth = depth + 1
        elseif t.token == PRE_TOKENS.CLOSE_PARENTHESES then
            if depth == 0 then
                break
            end
            depth = depth - 1
        elseif t.token == PRE_TOKENS.COMMA and depth == 0 then
            break
        end

        expr[#expr + 1] = t
        p = p + 1
    end

    return expr, p
end

local function get_index(self)
    local t = {}
    if self:expect(PRE_TOKENS.HASH_TAG) then
        self:consume()

        local index = self:CEexpect(PRE_TOKENS.NUMBER_INT)
        t = {
            index = tonumber(index.buf),
            kind = KINDS.INDEX
        }
    else
        t = {
            kind = KINDS.TOKEN,
            token = self:consume()
        }
    end
    return t
end

local function get_definition(self)
    local inti_tokens = {}
    while self:peek() do
        if self:expect(PRE_TOKENS.DOUBLE_COLON) or self:expect(PRE_TOKENS.NEW_LINE) then
            break
        end
        inti_tokens[#inti_tokens + 1] = get_index(self)
    end
    return inti_tokens
end

local function undef_macro(self, name)
    local inti_tokens = get_definition(self)

    local expr_tokens = {}

    local macro, i = self:search_macro(inti_tokens)

    table.remove(self.macros, i)

end

local function get_ifdefinition(self)
    local inti_tokens = {}
    while self:peek() do
        if self:expect(PRE_TOKENS.NEW_LINE) then
            break
        end
        inti_tokens[#inti_tokens + 1] = get_index(self)
    end
    return inti_tokens
end

local function is_active(self)
	for i = #self.if_stack, 1, -1 do
		local stack = self.if_stack[i]
		if not stack.active then
			return false
		end
	end
	return true
end

function directives.define(self)

    local inti_tokens = get_definition(self)

    local macro, i = self:search_macro(inti_tokens)
    if macro then
        local m_name = {}
        for _, v in ipairs(macro.init) do
            if v.kind == KINDS.TOKEN then
                m_name[#m_name + 1] = v.token.buf
            else
                m_name[#m_name + 1] = "#" .. v.index
            end
        end

        self:warn(string.format("Macro '%s' is already defined", table.concat(m_name, " ")))
        undef_macro(self, macro.name)
    end

    local expr_tokens = {}

    if self:expect(PRE_TOKENS.NEW_LINE) then
        goto _end_define
    end

    self:consume()

    while self:peek() do
        expr_tokens[#expr_tokens + 1] = get_index(self)

        if self:expect(PRE_TOKENS.NEW_LINE) then
            break
        end
    end

    ::_end_define::

    self.macros[#self.macros + 1] = {
        init = inti_tokens,
        expr = expr_tokens,
        name = tostring(#self.macros) .. " " .. math.random(1, 9999)
    }

end

function directives.undef(self)
    local inti_tokens = get_definition(self)

    local expr_tokens = {}

    local macro, i = self:search_macro(inti_tokens)

    table.remove(self.macros, i)

    -- self.macros[#self.macros + 1] = {
    --    init = inti_tokens,
    --    expr = expr_tokens
    -- }

end

function directives.ifdef(self)

    local inti_tokens = get_ifdefinition(self)

    local result, i = self:search_macro(inti_tokens)

	self.if_stack[#self.if_stack + 1] = {
		active = result ~= nil,
		branch_taken = false,
		elif_branch_taken = result ~= nil,
	}
end

function directives.elif(self)

    local inti_tokens = get_ifdefinition(self)

    local result, i = self:search_macro(inti_tokens)

	local top = self.if_stack[#self.if_stack]

	if top.branch_taken then
		self:error("Can't have two '#elif' after a else")
	end

	local something = top.elif_branch_taken

	self.if_stack[#self.if_stack] = {
		active = result ~= nil and not something,
		branch_taken = false,
		elif_branch_taken = something or result ~= nil
	}
end

function directives.ifndef(self)
    local inti_tokens = get_ifdefinition(self)

    local result, i = self:search_macro(inti_tokens)

	self.if_stack[#self.if_stack + 1] = {
		active = result == nil,
		branch_taken = false,
	}
end

directives["else"] = function (self)
	local top = self.if_stack[#self.if_stack]

	if top.branch_taken then
		self:error("Can't have two '#else' for the same if")
	end

	self.if_stack[#self.if_stack] = {
		active = not top.active and not top.elif_branch_taken,
		branch_taken = true
	}
end

function directives.endif(self)
	if #self.if_stack == 0 then
		self:error("can't use #endif in global scope")
	end

	self.if_stack[#self.if_stack] = nil
end

function directives.require(self)
	local name = self:consume()
	local file, err
	if name.token == PRE_TOKENS.STRING_LITERAL then
		file, err = file2io.open("./" .. name.buf, file2io.modes.read_binary)
	elseif name.token == PRE_TOKENS.LOWER then
		name = ""
		while self:peek() and self:peek().token ~= PRE_TOKENS.GREATER do
			local n = self:consume()
			name = name .. n.buf
		end
		self:consume()

		file, err = file2io.open("./" .. name, file2io.modes.read_binary)
	end
	if err then
		self:error(err)
	end

	local content = file:read()
	file:close()

	local tokens = lexer.tokenize(name, content)

	self:inject(tokens)
end

function _M.new(tokens, ARGUMENTS, file_path)
    local self = setmetatable({}, processor)

    self.ARGUMENTS = ARGUMENTS

    self.max_expansion = 2 ^ 3

    self.max_recursion_genereation = 2 ^ 3

    self.expansion = 0

    self.file_path = file_path

    self.if_stack = {}

    self.tokens = tokens

    self.stack = nil

    self.macros = {}

    self.last_token_index = 1

    self.pos = 1

    self.tags = {}

    self.result = {}

    self.expanding = {}

    local max = self.ARGUMENTS:GET_FLAG("-Mexp")
    if type(max) == "string" then
        self.max_expansion = tonumber(max)
        if not self.max_expansion or math.type(self.max_expansion) == "float" or self.max_expansion <= 0 then
            self.ARGUMENTS:ERROR("-Mexp can only be a positive integer number")
        end
    end

    local max = self.ARGUMENTS:GET_FLAG("-MRG")
    if type(max) == "string" then
        self.max_recursion_genereation = tonumber(max)
        if not self.max_recursion_genereation or math.type(self.max_recursion_genereation) == "float" or
            self.max_recursion_genereation <= 0 then
            self.ARGUMENTS:ERROR("-MRG can only be a positive integer number")
        end
    end

    return self
end

function processor:inject(tokens)
    for i = #tokens, 1, -1 do
		tokens[i].__from_preprocessor = true
        table.insert(self.tokens, self.pos, tokens[i])
    end
end

function processor:search_macro(tokens)
    for i, macro in ipairs(self.macros) do
        local equal = true
        if #macro.init ~= #tokens then
            goto continue
        end

        for j, token in ipairs(macro.init) do
            if not tokens[j] then
                equal = false
                break
            end

            if tokens[j].kind ~= token.kind then
                equal = false
                break
            end
            if token.kind == KINDS.INDEX then
                if tokens[j].index ~= token.index then
                    equal = false
                    break
                end
            else
                if tokens[j].token.buf ~= token.token.buf then
                    equal = false
                    break
                end
            end
        end

        if equal then
            return macro, i
        end
        ::continue::
    end
end

function processor:try_match_macro(macro)
    local p = self.pos
    local args = {}

    for _, part in ipairs(macro.init) do
        if part.kind == KINDS.TOKEN then
            local t = self:peek_at(p)
            if not t then
                return nil
            end

            if t.token ~= part.token.token or t.buf ~= part.token.buf then
                return nil
            end

            p = p + 1

        elseif part.kind == KINDS.INDEX then
            local expr, newp = capture_expr_at(self, p)
            if not expr or #expr == 0 then
                return nil
            end

            args[part.index] = expr
            p = newp
        end
    end

    return {
        end_pos = p,
        args = args
    }
end

function processor:apply_macro(macro, match)
    if (self.expanding[macro] or 0) > self.max_recursion_genereation then
        self:error(string.format("Recursive macro (%d) expansion detected: '%s'", self.max_recursion_genereation,
            macro.name or "<anonymous>"))
        return
    end

    if self.expansion > self.max_expansion then
        self:error(string.format("Max (%d) macro expansion reached: '%s'", self.max_expansion,
            macro.name or "<anonymous>"))
        return
    end

    self.pos = match.end_pos

    local expansion = {}

    for _, part in ipairs(macro.expr) do
        if part.kind == KINDS.INDEX then
            local arg = match.args[part.index]
            if arg then
                for _, tok in ipairs(arg) do
                    local t = tok
                    t.__from_macro = macro
                    expansion[#expansion + 1] = t
                end
            end
        else
            local t = part.token
            t.__from_macro = macro
            expansion[#expansion + 1] = t
        end
    end

    self.expanding[macro] = (self.expanding[macro] or 0) + #expansion
    self.expansion = self.expansion + 1

    self:inject(expansion)
end

function processor:match()
    for _, macro in ipairs(self.macros) do
        local m = self:try_match_macro(macro)
        if m then
            self:apply_macro(macro, m)
            return
        end
    end

    self:push_back(self:consume())
end

function processor:replace(otokens, ntokens)
    for i = 1, #otokens do
        if self.tokens[(i - 1) + self.pos] ~= otokens[i] then
            self:error("what?")
        end
        table.remove(self.tokens, self.pos)
    end

    for i = 1, #ntokens do
        table.remove(self.tokens, self.pos, ntokens[i])
    end
end

function processor:error(msg, raise)
    local line = self.line
    local column = self.column

    local left_off = 10
    local right_off = 10

    local tokens = {}
    do
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

    message[#message + 1] = string.format(string.format("PREPROCESSOR line %s column %s\n", line, column))
    message[#message + 1] = msg
    message[#message + 1] = "\n\n"

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
    os.exit(1)
end

function processor:warn(msg, raise)
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
    message[#message + 1] = ("\n")

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

    message = table.concat(message)

    self.ARGUMENTS:WARN(message)
end

function processor:info(msg)
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

function processor:CEexpect(pretoken, length)
    local p = self:peek(length)
    if not p or p.token ~= pretoken then
        self:error(string.format("Error expected ['%s'] but got ['%s']", pretoken, tostring((p or {}).token)))
    end
    return self:consume()
end

function processor:TCEexpect(tbl, length)
    local p = self:peek(length)
    if not p or not tbl[p.token] then
        self:error(string.format("Error expected [custom table] but got ['%s']", tostring((p or {}).token)))
    end
    return self:consume()
end

function processor:token_in_class(token, tbl)
    if not token then
        self:error("Expected token but received ['nil']")
    end
    if not tbl then
        self:error("Compiler error. Expected custom table but received ['nil']")
    end
    return tbl[token.token]
end

function processor:Econsume()
    if not self:peek() then
        self:error("Inconplete Consume")
    end

    return self:consume()
end

function processor:consume()
    local t = self.tokens[self.pos]
    self.pos = self.pos + 1
    self.last_token_index = self.pos

    if t and t.__from_macro then
        local m = t.__from_macro
        self.expanding[m] = (self.expanding[m] or 1) - 1
        if self.expanding[m] <= 0 then
            self.expanding[m] = nil
        end
    end

    return t
end

function processor:peek(length)
    length = length or 0
    local t = self.tokens[self.pos + length]
    if t then
        self.line = t.line
        self.column = t.column
    end
    return t
end

function processor:peek_at(pos)
    return self.tokens[pos]
end

function processor:push_back(content)
    if content.token == PRE_TOKENS.LINE_COMMENT then
        return
    end
    if content.token == PRE_TOKENS.NEW_LINE then
        local t = self.result[#self.result]
        if t and t.token == PRE_TOKENS.NEW_LINE then
            return
        end
    end
	if is_active(self) then
    	self.result[#self.result + 1] = content
	end
end

function processor:Eexpect(pretoken, length)
    local p = self:peek(length)
    if not p or p.token ~= pretoken then
        self:error(string.format("Error expected ['%s'] but got ['%s']", pretoken, tostring((p or {}).token)))
    end
    return true
end

function processor:expect(pretoken, length)
    local p = self:peek(length)
    if not p then
        return false
    end
    if p.token ~= pretoken then
        return false
    end
    return p
end

function processor:Texpect(tbl, length)
    local p = self:peek(length)
    if not p then
        return false
    end
    if not tbl[p.token] then
        return false
    end
    return p
end

function processor:Cexpect(pretoken, length)
    if not self:peek(length) then
        return false
    end
    if self:peek().token ~= pretoken then
        return false
    end
    local t = self:consume()
    return t
end

function processor:start()
    while self.pos <= #self.tokens do
        if self:expect(PRE_TOKENS.PREPROCESSOR_TOKEN) then
            local name = self:consume().buf:sub(2, -1)
            directives[name](self)
        else
            local expanded = false
            for _, macro in ipairs(self.macros) do
                local m = self:try_match_macro(macro)
                if m then
                    self:apply_macro(macro, m)
                    expanded = true
                    break
                end
            end

            if not expanded then
                self:push_back(self:consume())
            end
        end
    end

	if #self.if_stack > 0 then
		self:error("(#ifdef, #ifndef) scope was not closed")
	end

	for k, token in ipairs(self.result) do -- clear trash from preprocessor
		token.__from_macro = nil
	end

    return self.result
end

return _M
