-- preprocessor directive
local _M = {}

local inspect = require("inspect")
local file2io = require("file2io")
local color8 = require("color8")

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
        if not t then break end

        if t.token == PRE_TOKENS.OPEN_PARENTHESES then
            depth = depth + 1
        elseif t.token == PRE_TOKENS.CLOSE_PARENTHESES then
            if depth == 0 then break end
            depth = depth - 1
        elseif t.token == PRE_TOKENS.COMMA and depth == 0 then
            break
        end

        expr[#expr+1] = t
        p = p + 1
    end

    return expr, p
end


local function get_index(self)
    local t = {}
    if self:expect(PRE_TOKENS.MODULE) then
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
        if self:expect(PRE_TOKENS.EQUAL_ASSIGNING) or self:expect(PRE_TOKENS.NEW_LINE) then
            break
        end
        inti_tokens[#inti_tokens + 1] = get_index(self)
    end
	return inti_tokens
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

function directives.define(self)
    ---- print(inspect(self.tokens))

    local inti_tokens = get_definition(self)
	
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

    -- print(inspect(inti_tokens))
    -- print("EQUAL")
    -- print(inspect(expr_tokens))
    -- print("DEFINE")

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

	for i, macro in ipairs(self.macros) do
		local equal = true

		print("MACRO", macro.name)

		for j, token in ipairs(macro.init) do
			if not inti_tokens[j] then
				equal = false
			end

			print("MACRO", inti_tokens[j].token.token, token.token.token)

			if inti_tokens[j].token.token ~= token.token.token then
				equal = false
			end
		end

		if equal then
			print("REMOVE UNDEF", i)
			table.remove(self.macros, i)
			break
		end
	end

    self.macros[#self.macros + 1] = {
        init = inti_tokens,
        expr = expr_tokens
    }

end

function directives.ifdef(self)
	print("IFDEF")
	
    local inti_tokens = get_ifdefinition(self)

	print(inspect(inti_tokens))

	error()
end

function directives.endif(self)
    local inti_tokens = {}
end

function _M.new(tokens)
    local self = setmetatable({}, processor)

    self.tokens = tokens

    self.stack = nil

    self.macros = {}

    self.last_token_index = 1

    self.pos = 1

    self.tags = {}

    self.result = {}

    return self
end

function processor:inject(tokens)
    for i = #tokens, 1, -1 do
        table.insert(self.tokens, self.pos, tokens[i])
    end
end

function processor:try_match_macro(macro)
    local p = self.pos
    local indexes = {}

    for _, roken in ipairs(macro.init) do
        if roken.kind == KINDS.TOKEN then
            local t = self:peek_at(p)
            if not t or t.token ~= roken.token.token or t.buf ~= roken.token.buf then
                return nil
            end
            p = p + 1

        elseif roken.kind == KINDS.INDEX then
            local expr, newp = capture_expr_at(self, p)
            indexes[roken.index] = expr
            p = newp
        end
    end

    return {
        end_pos = p,
        args = indexes
    }
end

function processor:apply_macro(macro, match)
    self.pos = match.end_pos

    local expansion = {}

    for _, part in ipairs(macro.expr) do
        if part.kind == KINDS.INDEX then
            for _, tok in ipairs(match.args[part.index]) do
                expansion[#expansion + 1] = tok
            end
        else
            expansion[#expansion + 1] = part.token
        end
    end

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

    -- nenhum macro casou → consome 1 token normal
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

function processor:error(msg)
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

    io.stderr:write(msg)
    io.stderr:write(string.format("\nError in PREPROCESSOR line %s column %s", line, column))
    io.stderr:write("\n\n")

    for i, token in ipairs(tokens) do
        io.stderr:write(token.token.buf)
        if #token.token.buf > 0 then
            io.stderr:write(" ")
        end
    end
    io.stderr:write("\n")

    color8.error = true
    color8.fcolor(0, 128, 128)
    for i, token in ipairs(tokens) do
        if #token.token.buf > 0 then
            for j = 1, #token.token.buf do
                if token.index == 0 then
                    color8.fcolor(255, 0, 0)
                    io.stderr:write("^")
                else
                    color8.fcolor(0, 128, 128)
                    io.stderr:write("-")
                end
            end
            color8.fcolor(0, 128, 128)
            if i ~= #tokens then
                io.stderr:write("-")
            end

        end
    end
    color8.fcolor(200, 200, 200)
    io.stderr:write("\n")
    os.exit(1)
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
	--self.stack[#self.stack + 1] = t
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
    self.result[#self.result + 1] = content
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
        if self:expect(PRE_TOKENS.HASH_TAG) then
            self:consume()
            local name = self:CEexpect(PRE_TOKENS.NAME).buf
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

    return self.result
end


return _M
