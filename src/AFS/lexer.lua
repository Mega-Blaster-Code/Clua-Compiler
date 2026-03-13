local _M = {}

local inspect = require("C_inspect")

local FLAG_TOKENS = {
    SEMICOLON = "__SEMICOLON",
    NAME = "__NAME",

    COMMA = "__COMMA",
    COLON = "__COLON",

    POINTER = "__POINTER",

    CALL = "__CALL",

    LINE_COMMENT = "__LINE_COMMENT",

    NUMBER_INT = "__NUMBER",

    CUSTOM_FLAG = "__CUSTOM_FLAG",
    BUILTIN_FLAG = "__BUILTIN_FLAG",
    PLUS = "__PLUS"
}

local matchs_tokens = {{
    pattern = "^;$",
    token = FLAG_TOKENS.SEMICOLON
}, {
    pattern = "^%=%=.*$",
    token = FLAG_TOKENS.LINE_COMMENT
}, {
    pattern = "^%:$",
    token = FLAG_TOKENS.COLON
}, {
    pattern = "^=.$",
    token = FLAG_TOKENS.POINTER
}, {
    pattern = "^@$",
    token = FLAG_TOKENS.CALL
}, {
    pattern = "^%-%-",
    token = FLAG_TOKENS.BUILTIN_FLAG
}, {
    pattern = "^%-",
    token = FLAG_TOKENS.CUSTOM_FLAG
}, {
    pattern = "[^%-]*[^@^=^:^;]",
    token = FLAG_TOKENS.NAME
},{
    pattern = "^%+$",
    token = FLAG_TOKENS.PLUS
}}

local lexer = {}
lexer.__index = lexer

function _M.new(arg)
    local self = setmetatable({}, lexer)

    self.args = arg
    self.arg_pos = 1
    self.pos = 1

    self.buffer = {}

    self.tokens = {}

    self:start()

    return self.tokens
end

function lexer:consume()
    local t = self.args[self.arg_pos]:sub(self.pos, self.pos)
    self.pos = self.pos + 1
    return t
end

function lexer:peek(length)
    length = length or 0
    if self.pos > #(self.args[self.arg_pos] or "") then
        return
    end
    return self.args[self.arg_pos]:sub(self.pos + length, self.pos + length)
end

function lexer:push_back(str)
    self.buffer[#self.buffer + 1] = str
end

function lexer:new_token(token, buffer)
    self.tokens[#self.tokens + 1] = {
        token = token,
        buf = buffer or table.concat(self.buffer)
    }
    -- self.pos = 1
    -- self.arg_pos = self.arg_pos + 1
    self.buffer = {}
end

function lexer:get_buffer()
	if self:peek():match("%c") then
       	self:consume()
        while self:peek() and self:peek():match("%c") do
            self:consume()
        end
    end

    if self:peek():match("[^@^=^:^;]") then
        self:push_back(self:consume())
        while self:peek() and self:peek():match("[^@^=^:^;]") do
            self:push_back(self:consume())
        end
        return
    end

    if self:peek():match(":") then
        self:push_back(self:consume())
        return
    end

    if self:peek():match("=") then
		self:push_back(self:consume())
        if self:peek() and self:peek() == "." then
            self:push_back(self:consume())
        end
        return
    end

    if self:peek():match("-") then
		self:push_back(self:consume())
        if self:peek(1) and self:peek(1) == "-" then
            self:push_back(self:consume())
            while self:peek() do
                self:push_back(self:consume())
            end
            return
        end
		return
    end

    if self:peek():match("@") then
        self:push_back(self:consume())
        return
    end

	if self:peek():match(";") then
        self:push_back(self:consume())
        return
    end

	--print(self:peek())
end

function lexer:start()
    while self.args[self.arg_pos] and self:peek() do

        self:get_buffer()

        local buffer = table.concat(self.buffer)
        for i, m in ipairs(matchs_tokens) do
            if buffer:match(m.pattern) then
                self:new_token(m.token, buffer)
                goto continue
            end
        end

        error("'" .. buffer .. "'")

        ::continue::

        --print(self.pos, #self.args[self.arg_pos])
        if self.pos > #self.args[self.arg_pos] then
            self.arg_pos = self.arg_pos + 1
            self.pos = 1
			self:new_token(FLAG_TOKENS.SEMICOLON, ";")
        end
    end

end

return _M
