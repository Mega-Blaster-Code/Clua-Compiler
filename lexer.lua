-- SOURCE -> lexer -> tokens
local inspect = require("inspect")
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
        pattern = "^'.'$",
        token = PRE_TOKENS.CHAR_LITERAL
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
    }}
end

function _M.tokenize(str)
    str = str:gsub("\r\n", "\n")
    local char_pos = 1

    local line = 1
    local column = 1

    local function consume()
        local c = str:sub(char_pos, char_pos)
        char_pos = char_pos + 1
        column = column + 1
        if c == "\n" then
            line = line + 1
            column = 1
        end
        return (#c > 0 and c) or nil
    end

    local function peek(length)
        length = length or 0
        local c = str:sub(length + char_pos, length + char_pos)
        return (#c > 0 and c) or nil
    end

    local tokens = {}

    local buf = ""

    local function new_token(buffer, token)
        table.insert(tokens, {
            buf = buffer,
            token = token,
            line = line,
            column = column
        })
    end

    local function tpeek(length)
        length = length or 0
        local token = tokens[#tokens + length]
        return token
    end

    local function push_back(char)
        buf = buf .. char
    end

    local is_string = false

    local function match_patterns()
        if peek() and peek():match("[ \t]") then
            while peek() and peek():match("[ \t]") do
                consume()
            end
            return true
        end

        if peek() and peek() == "\n" then
            push_back(consume())
            buf = ""
            return true
        end

        if peek():match("\"") then
            consume()
            is_string = not is_string

            if is_string then
                while not peek():match("\"") do
                    push_back(consume())
                    if not peek() then
                        error("Unfinished string")
                    end
                end
                consume()
                is_string = false
                new_token(buf, PRE_TOKENS.STRING)
                buf = ""
                return true
            end
        end

        if peek() and peek() == "'" and peek(1) then
            if peek(2) and peek(2) == "'" then
                consume()
                local c = consume()
                consume()

                new_token(c, PRE_TOKENS.CHAR_LITERAL)
                buf = ""
                return true
            else
                error("Invalid Char literal")
            end
        end

        if peek():match("[%a_]") then
            push_back(consume())
            while peek() and peek():match("[%w_]") do
                push_back(consume())
            end
            return false
        end

        if peek() == "." and peek(1) and peek(1):match("%d") then
            push_back(consume())
            while peek() and peek():match("%d") do
                push_back(consume())
            end
            new_token(buf, PRE_TOKENS.NUMBER_FLOAT)
            buf = ""
            return true
        end

        if peek():match("%d") then

            while peek() and peek():match("%d") do
                push_back(consume())
            end

            if peek() == "." then
                push_back(consume())
                while peek() and peek():match("%d") do
                    push_back(consume())
                end
                new_token(buf, PRE_TOKENS.NUMBER_FLOAT)
            else
                new_token(buf, PRE_TOKENS.NUMBER_INT)
            end

            buf = ""
            return true
        end

        if peek() and peek():match("[%-%+%*/]") then
            if peek():match("%-") and peek(1):match("%-") then
                push_back(consume())
                push_back(consume())
                while peek() and peek() ~= "\n" do
                    push_back(consume())
                end
                return false
            end
            push_back(consume())
            return false
        end

        if peek() and peek():match("[%(%{%[%)%}%];,%.%:&]") then
            push_back(consume())
            return false
        end

        if peek() and peek():match("[=~]") then
            push_back(consume())
            if peek() and peek():match("=") then
                push_back(consume())
            end
            return false
        end

        if peek() and peek():match(">") then
            push_back(consume())
            if peek() and peek():match("=") then
                push_back(consume())
            end
            return false
        end

        if peek() and peek():match("<") then
            push_back(consume())
            if peek() and peek():match("=") then
                push_back(consume())
            end
            return false
        end
    end

    local function match_token()

        if KEYWORDS[buf] then
            new_token(buf, KEYWORDS[buf])
            return true
        end

        for _, info in ipairs(matchs_tokens) do
            if buf:match(info.pattern) then
                new_token(buf, info.token)
                return true
            end
        end

        return false
    end

    while peek() do

        local skip = match_patterns()

        local result = match_token()

        if not skip and not result then
            error(string.format("Somethin went wrong line:%d column:%d   ;  buf['%s'] peek['%s'] %d/%d", line, column,
                buf, peek(), char_pos - 1, #str))
        end

        buf = ""
    end

    for i, token in ipairs(tokens) do
        if not token.token then
            error(string.format(
                "Error while generating tokens. Token don't have a 'token' key with info line:%d column:%d  ; buf['%s']",
                token.line, token.column, tostring(token.buf)))
        end

        if not token.buf then
            error(string.format(
                "Error while generating tokens. Token '%s' don't have a valid buffer with info line:%d column:%d  ; buf['%s']",
                token.token, token.line, token.column, tostring(token.buf)))
        end
    end

    return tokens
end

return _M
