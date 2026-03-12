-- SOURCE -> lexer -> tokens
local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")

local PRE_TOKENS, KEYWORDS

do
    local info = require("tokens")
    PRE_TOKENS, KEYWORDS = info[1], info[2]
end

local _M = {}
local matchs_tokens = {}

do
    matchs_tokens = {{
        pattern = "^;$",
        token = PRE_TOKENS.SEMICOLON
    }, {
        pattern = "^\n$",
        token = PRE_TOKENS.NEW_LINE
    }, {
        pattern = "^\t$",
        token = PRE_TOKENS.TAB
    }, {
        pattern = "^'.'$",
        token = PRE_TOKENS.CHAR_LITERAL
    }, {
        pattern = "^outside$",
        token = PRE_TOKENS.OUTSIDE
    }, {
        pattern = "^exused$",
        token = PRE_TOKENS.EXUSED
    }, {
        pattern = "^static$",
        token = PRE_TOKENS.STATIC
    }, {
        pattern = "^intern$",
        token = PRE_TOKENS.INTERN
    }, {
        pattern = "^inend$",
        token = PRE_TOKENS.INEND
    }, {
        pattern = "^#$",
        token = PRE_TOKENS.HASH_TAG
    }, {
        pattern = "^#.*$",
        token = PRE_TOKENS.PREPROCESSOR_TOKEN
    }, {
        pattern = "^typedef$",
        token = PRE_TOKENS.TYPEDEF
    }, {
        pattern = "^%-%-.*$",
        token = PRE_TOKENS.LINE_COMMENT
    }, {
        pattern = "^%($",
        token = PRE_TOKENS.OPEN_PARENTHESES
    }, {
        pattern = "^%)$",
        token = PRE_TOKENS.CLOSE_PARENTHESES
    }, {
        pattern = "^,$",
        token = PRE_TOKENS.COMMA
    }, {
        pattern = "^%.$",
        token = PRE_TOKENS.DOT
    }, {
        pattern = "^%:$",
        token = PRE_TOKENS.COLON
    }, {
        pattern = "^%::$",
        token = PRE_TOKENS.DOUBLE_COLON
    }, {
        pattern = "^{$",
        token = PRE_TOKENS.OPEN_BRACES
    }, {
        pattern = "^}$",
        token = PRE_TOKENS.CLOSE_BRACES
    }, {
        pattern = "^%[$",
        token = PRE_TOKENS.OPEN_BRACKETS
    }, {
        pattern = "^%]$",
        token = PRE_TOKENS.CLOSE_BRACKETS
    }, {
        pattern = "^=$",
        token = PRE_TOKENS.EQUAL_ASSIGNING
    }, {
        pattern = "^==$",
        token = PRE_TOKENS.EQUAL_COMPARISON
    }, {
        pattern = "^~=$",
        token = PRE_TOKENS.DIFFERENT
    }, {
        pattern = "^>$",
        token = PRE_TOKENS.GREATER
    }, {
        pattern = "^>=$",
        token = PRE_TOKENS.GREATER_OR_EQUAL
    }, {
        pattern = "^<$",
        token = PRE_TOKENS.LOWER
    }, {
        pattern = "^<=$",
        token = PRE_TOKENS.LOWER_OR_EQUAL
    }, {
        pattern = "^[%a_][%w_]*$",
        token = PRE_TOKENS.NAME
    }, {
        pattern = "^&$",
        token = PRE_TOKENS.AMPERSAND
    }, {
        pattern = "^%-$",
        token = PRE_TOKENS.MINUS
    }, {
        pattern = "^%+$",
        token = PRE_TOKENS.PLUS
    }, {
        pattern = "^%*$",
        token = PRE_TOKENS.ASTERISK
    }, {
        pattern = "^/$",
        token = PRE_TOKENS.DIVIDE
    }, {
        pattern = "^//$",
        token = PRE_TOKENS.INT_DIVIDE
    }, {
        pattern = "^%:%:$",
        token = PRE_TOKENS.DOUBLE_COLON
    }, {
        pattern = "^&$",
        token = PRE_TOKENS.ADDRESS_OF
    }, {
        pattern = "^%%$",
        token = PRE_TOKENS.MODULE
    }, {
        pattern = "^%!$",
        token = PRE_TOKENS.MODULE
    }}
end

local valid_escape_sequence = {
    a = '\a',
    b = '\b',
    f = '\f',
    n = '\n',
    r = '\r',
    t = '\t',
    v = '\v',
    ["\\"] = '\\',
    ["'"] = '\'',
    ["\""] = '\"',
    ["0"] = '\0'
}

local function unescape(s)
    return s:gsub("\\(.)", function(c)
        return valid_escape_sequence[c] or c
    end)
end

local lexer = {}
lexer.__index = lexer

function _M.new(file_path, str, ARGUMENTS)
    str = str:gsub("\r\n", "\n")

    local self = setmetatable({}, lexer)

    self.ARGUMENTS = ARGUMENTS

    self.file_path = file_path
    self.str = str
	self.str_size = #str

    self.pos = 1

    self.RAW_C = {}

    self.RAW_MODE = false

    self.line = 1
    self.column = 1

    self.tokens = {
		bss = {}
	}

    self.buffer = {}

    return self
end

function lexer:peek(length)
	if self.pos > self.str_size then
		return nil
	end
    return string.char(self.str:byte(self.pos + (length or 0)))
end

function lexer:Tpeek(length)
    return self.tokens[#self.tokens + (length or 0)]
end

function lexer:consume()
    local _c = self:peek()
    self.pos = self.pos + 1
    if _c == "\n" then
        self.line = self.line + 1
        self.column = 1
    end
    return _c
end

local function buildMessage(msg, self)
    local line = {}

    line[#line + 1] = string.format("LEXER ERROR [\"%s\"] %sline:%d column:%d%s", self.file_path,
        color8.sfcolor(50, 150, 255), self.line, self.column, color8.sreset())
    line[#line + 1] = string.format("%s", msg)

    return table.concat(line, "\n")
end

function lexer:error(msg)
    local b_msg = buildMessage(msg, self)
    self.ARGUMENTS:ERROR(b_msg)
end

function lexer:clearBuffer()
    self.buffer = {}
end

function lexer:newToken(token)
    if self.RAW_MODE then
        return
    end
    self.tokens[#self.tokens + 1] = {
        buf = table.concat(self.buffer),
        token = token,
        line = self.line,
        column = self.column
    }

    self:clearBuffer()
end

function lexer:pushBack(char)
    if self.RAW_MODE then
        self.RAW_C[#self.RAW_C + 1] = char
    end
    self.buffer[#self.buffer + 1] = char
end

function lexer:matchPatterns()
    if self:peek() and self:peek():match("[ ]") then
        while self:peek() and self:peek():match("[ ]") do
            if self.RAW_MODE then
                self:pushBack(self:consume())
                return true
            else
                self:consume()
            end
        end
        return true
    end

    if self:peek() and self:peek() == "\n" then
        self:pushBack(self:consume())
        return true
    end

    if self:peek() and self:peek() == "\t" then
        self:pushBack(self:consume())
        return true
    end

    if self:peek():match("\"") then
        self:consume()

        local start = {
            line = self.line,
            column = self.column
        }

        self:clearBuffer()
        if self.RAW_MODE then
            self:pushBack("\"")
            while self:peek() ~= "\"" do
                local c = self:consume()
                self:pushBack(c)

                if c == "\\" then
                    if not self:peek() then
                        self:error("Invalid string")
                    end
                    local c = self:consume()
                    self:pushBack(c)
                end

                if not self:peek() then
                    self:error("Invalid string")
                end
            end
            local c = self:consume()
            self:pushBack("\"")
            self:newToken(PRE_TOKENS.STRING_LITERAL)

            return true
        end

        while self:peek() ~= "\"" do
            local c = self:consume()
			self:pushBack(c)
        end
		
        self:consume()

		self:newToken(PRE_TOKENS.STRING_LITERAL)
		
        self:clearBuffer()

        return true
    end
	
    if self:peek() == "-" and self:peek(1) == "-" and self:peek(2) == "-" and self:peek(3) and self:peek(4) == "*" then
        self:consume()
        self:consume()
        self:consume()
        self:consume()

        local start = {
            line = self.line,
            column = self.column
        }

        while true do
            if not self:peek() then
                self:error("Unfinished multi-line comment", start.line, start.column)
            end

            if self:peek() == "*" and self:peek(1) == "-" and self:peek(2) == "-" and self:peek(3) == "-" and
                self:peek(4) == "-" then
                self:consume()
                self:consume()
                self:consume()
                self:consume()
                self:consume()
                break
            end

            self:consume()
        end

        self:newToken(PRE_TOKENS.LINE_COMMENT)
        self:clearBuffer()
        return true
    end

    if self:peek() and self:peek() == "'" and self:peek(1) then
        if (self:peek(2) and self:peek(2) == "'") or (self:peek(3) and self:peek(3) == "'") then
            self:consume()
            local c = self:consume()
            local code = nil
            if c == "\\" then
                if not self:peek() then
                    self:error("Invalid escape sequence", self.line, self.column)
                end
                code = self:consume()

                if not valid_escape_sequence[code] then
                    self:error("Invalid escape sequence", self.line, self.column)
                end
            end

            if self:peek() ~= "'" then
                self:error("Invalid Char literal")
            end

            self:consume()

            if code then
				self:clearBuffer()
				self.buffer = {tostring(string.byte(unescape(c .. code)))}
                self:newToken(PRE_TOKENS.NUMBER_INT)
            else
				self:clearBuffer()
				self.buffer = {tostring(string.byte(c))}
                self:newToken(PRE_TOKENS.NUMBER_INT)
            end
            self:clearBuffer()
            return true
        else
            self:error("Invalid Char literal")
        end
    end

    if self:peek() == "e" then
        local exstr = "extern"
        local enstr = "exend"
        if not self.RAW_MODE then
            local equal = true
            for i = 1, #exstr do
                local char = exstr:sub(i, i)
                local t_char = self:peek(i - 1)

                if char ~= t_char then
                    equal = false
                    break
                end
            end

            if equal then
                for i = 1, #exstr, 1 do
                    self:pushBack(self:consume())
                end
                self:newToken(PRE_TOKENS.EXTERN)
                self.RAW_MODE = true
                self.RAW_C = {}
                return true
            end
        else

            local equal = true
            for i = 1, #enstr do
                local char = enstr:sub(i, i)
                local t_char = self:peek(i - 1)
                if char ~= t_char then
                    equal = false
                    break
                end
            end

            if equal then
                self.RAW_MODE = false

				self:clearBuffer()
				self.buffer = {table.concat(self.RAW_C)}
                self:newToken(PRE_TOKENS.RAW_C)

                for i = 1, #exstr, 1 do
                    self:consume()
                end

                return true
            end
        end
    end

    if self:peek():match("[%a_]") then
        self:pushBack(self:consume())
        while self:peek() and self:peek():match("[%w_]") do
            self:pushBack(self:consume())
        end
        return false
    end

    if self:peek():match("#") and self:peek(1) and self:peek(1):match("[%a]") then
        self:pushBack(self:consume())
        while self:peek() and self:peek():match("[%a]") do
            self:pushBack(self:consume())
        end
        return false
    end

    -- if self:peek():match("@") and self:peek(1) and self:peek(1):match("[%a]") then
    --	self:pushBack(self:consume())
    --	while self:peek() and self:peek():match("[%a]") do
    --		self:pushBack(self:consume())
    --	end
    --	return false
    -- end

    if self:peek():match("#") then
        self:pushBack(self:consume())
        return false
    end

    if self:peek() == "." and self:peek(1) and self:peek(1):match("%d") then
        self:pushBack(self:consume())
        while self:peek() and self:peek():match("%d") do
            self:pushBack(self:consume())
        end
        self:newToken(PRE_TOKENS.NUMBER_FLOAT)
        self:clearBuffer()
        return true
    end

    if self:peek():match("%d") then

        while self:peek() and self:peek():match("%d") do
            self:pushBack(self:consume())
        end

        if self:peek() == "." then
            self:pushBack(self:consume())
            while self:peek() and self:peek():match("%d") do
                self:pushBack(self:consume())
            end
            self:newToken(PRE_TOKENS.NUMBER_FLOAT)
        else
            self:newToken(PRE_TOKENS.NUMBER_INT)
        end

        self:clearBuffer()
        return true
    end

    if self:peek() and self:peek():match("[%-%+%*/%%]") then
        if self:peek():match("%-") and self:peek(1):match("%-") then
            self:pushBack(self:consume())
            self:pushBack(self:consume())
            while self:peek() and self:peek() ~= "\n" do
                self:pushBack(self:consume())
            end
            return false
        end

        if self:peek():match("%-") and self:peek(1):match(">") then
            self:consume()
            self:consume()
			self:pushBack("->")
            self:newToken(PRE_TOKENS.POINTER)
            self:clearBuffer()
            return true
        end

        if self:peek() == "/" and self:peek(1) == "/" then
            self:pushBack(self:consume())
            self:pushBack(self:consume())
            return false
        end

        self:pushBack(self:consume())
        return false
    end

    if self:peek() and self:peek():match("[%(%{%[%)%}%];,%.:&]") then
        if self:peek() and self:peek():match(":") then
            self:pushBack(self:consume())
            return false
        end
        self:pushBack(self:consume())
        return false
    end

    if self:peek() and self:peek():match("[~=]") then
        self:pushBack(self:consume())
        if self:peek() and self:peek():match("=") then
            self:pushBack(self:consume())
        end
        return false
    end

    if self:peek() and self:peek():match(">") then
        self:pushBack(self:consume())
        if self:peek() and self:peek():match("=") then
            self:pushBack(self:consume())
        end
        return false
    end

    if self:peek() and self:peek():match("<") then
        self:pushBack(self:consume())
        if self:peek() and self:peek():match("=") then
            self:pushBack(self:consume())
        end
        return false
    end
end

function lexer:matchTokens()
	local buf = table.concat(self.buffer)

	if KEYWORDS[buf] then
		self:newToken(KEYWORDS[buf])
		return true
	end

	for _, info in ipairs(matchs_tokens) do
		if buf:match(info.pattern) then
			self:newToken(info.token)
			return true
		end
	end

	return false
end

function lexer:start()
    while self:peek() do

        local skip = self:matchPatterns()

        local result = self:matchTokens()

        if not skip and not result then
            self:error(string.format("Can't match buffer '%s' with peek(1) = '%s'", inspect(self.buffer), tostring(self:peek())))
        end

        self:clearBuffer()
    end

    for i, token in ipairs(self.tokens) do
        if not token.token then
            self:error(string.format("error while generating tokens. Token don't have a 'token' key ; buffer['%s']",
                tostring(token.buf)))
        end

        if not token.buf then
            self:error(string.format(
                "self:error while generating tokens. Token '%s' don't have a valid buffer with info ; buffer['%s']",
                token.token, tostring(token.buf)))
        end
    end

    return self.tokens
end

return _M
