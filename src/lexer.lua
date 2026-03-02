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
    ["0"] = '\0',
}

local function unescape(s)
    return s:gsub("\\(.)", function(c)
        return valid_escape_sequence[c] or c
    end)
end

function _M.tokenize(file_path, str)

    str = str:gsub("\r\n", "\n")

    local __RAW_MODE = false
    local __RAW_C = {}

    local char_pos = 1

    local line = 1
    local column = 1
    local row = 1

    local function error_gene(msg, l, c)
        l = l or line
        c = c or column - 1
        io.stderr:write(string.format("error_gene while consuming file '%s': (Line %d; Column %d)\n", file_path, l, c))
        io.stderr:write(string.format("%s", msg))
        os.exit()
    end

    local function consume()
        local c = str:sub(char_pos, char_pos)
        char_pos = char_pos + 1
        column = column + 1
        if c == "\n" then
            line = line + 1
            column = 1
            row = row + 1
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
        if __RAW_MODE then
            return
        end
        table.insert(tokens, {
            buf = buffer,
            token = token,
            line = line,
            column = column,
            row = row
        })
        buf = ""
    end

    local function tpeek(length)
        length = length or 0
        local token = tokens[#tokens + length]
        return token
    end

    local function push_back(char)
        if __RAW_MODE then
            __RAW_C[#__RAW_C + 1] = char
        end
        buf = buf .. char
    end

    local is_string = false
    local is_comment = false

    local function match_patterns()
        if peek() and peek():match("[ ]") then
            while peek() and peek():match("[ ]") do
                if __RAW_MODE then
                    push_back(consume())
                    return true
                else
                    consume()
                end
            end
            return true
        end

        if peek() and peek() == "\n" then
            push_back(consume())
            return true
        end

        if peek() and peek() == "\t" then
            push_back(consume())
            return true
        end

        if peek():match("\"") then
            consume()

            local start = {
                line = line,
                column = column
            }

            buf = ""

            if __RAW_MODE then

                push_back("{")
                new_token(buf, PRE_TOKENS.OPEN_BRACKETS)

                while peek() ~= "\"" do
                    local c = consume()

                    if c == "\\" then
                        local code = consume()
                        if not code then
                            error_gene("Invalid string")
                        end
						buf = ""
						push_back(tostring(string.byte(unescape(c .. code))))
                        new_token(buf, PRE_TOKENS.NUMBER_INT)
                    else
						buf = ""
						push_back(tostring(string.byte(c)))
                        new_token(buf, PRE_TOKENS.NUMBER_INT)

                        if not peek() then
                            error_gene("Invalid string")
                        end
						
                    end
					buf = ""
					push_back(", ")
					new_token(buf, PRE_TOKENS.COMMA)
                end

                consume()

                buf = ""

                push_back("0")
                new_token(buf, PRE_TOKENS.NUMBER_INT)

                push_back("}")
                new_token(buf, PRE_TOKENS.CLOSE_BRACKETS)

                return true
            end

            push_back("[")
            new_token(buf, PRE_TOKENS.OPEN_BRACKETS)

            while peek() ~= "\"" do
                local c = consume()

                if c == "\\" then
                    local code = consume()
                    if not code then
                        error_gene("Invalid string")
                    end
                    new_token(tostring(string.byte(unescape(c .. code))), PRE_TOKENS.NUMBER_INT)
                else
                    new_token(tostring(string.byte(c)), PRE_TOKENS.NUMBER_INT)
                    if not peek() then
                        error_gene("Invalid string")
                    end
                    push_back(",")
                    new_token(buf, PRE_TOKENS.COMMA)
                end
            end

            consume()

            buf = ""

            push_back("0")
            new_token(buf, PRE_TOKENS.NUMBER_INT)

            push_back("]")
            new_token(buf, PRE_TOKENS.CLOSE_BRACKETS)

            return true
        end

        if peek() == "-" and peek(1) == "-" and peek(2) == "-" and peek(3) and peek(4) == "*" then
            consume()
            consume()
            consume()
            consume()

            local start = {
                line = line,
                column = column
            }

            while true do
                if not peek() then
                    error_gene("Unfinished multi-line comment", start.line, start.column)
                end

                if peek() == "*" and peek(1) == "-" and peek(2) == "-" and peek(3) == "-" and peek(4) == "-" then
                    consume()
                    consume()
                    consume()
                    consume()
                    consume()
                    break
                end

                consume()
            end

            new_token(buf, PRE_TOKENS.LINE_COMMENT)
            buf = ""
            return true
        end

        if peek() and peek() == "'" and peek(1) then
            if (peek(2) and peek(2) == "'") or (peek(3) and peek(3) == "'") then
                consume()
                local c = consume()
                local code = nil
                if c == "\\" then
                    if not peek() then
                        error_gene("Invalid escape sequence", line, column)
                    end
                    code = consume()

                    if not valid_escape_sequence[code] then
                        error_gene("Invalid escape sequence", line, column)
                    end
                end

                if peek() ~= "'" then
                    error_gene("Invalid Char literal")
                end

                consume()

                if code then
                    new_token(tostring(string.byte(unescape(c .. code))), PRE_TOKENS.NUMBER_INT)
                else
                    new_token(tostring(string.byte(c)), PRE_TOKENS.NUMBER_INT)
                end
                buf = ""
                return true
            else
                error_gene("Invalid Char literal")
            end
        end

        if peek() == "e" then
            local exstr = "extern"
            local enstr = "exend"
            if not __RAW_MODE then
                local equal = true
                for i = 1, #exstr do
                    local char = exstr:sub(i, i)
                    local t_char = peek(i - 1)

                    if char ~= t_char then
                        equal = false
                        break
                    end
                end

                if equal then
                    for i = 1, #exstr, 1 do
                        push_back(consume())
                    end
                    new_token(buf, PRE_TOKENS.EXTERN)
                    __RAW_MODE = true
                    __RAW_C = {}
                    return true
                end
            else

                local equal = true
                for i = 1, #enstr do
                    local char = enstr:sub(i, i)
                    local t_char = peek(i - 1)
                    if char ~= t_char then
                        equal = false
                        break
                    end
                end

                if equal then
                    __RAW_MODE = false

                    new_token(table.concat(__RAW_C), PRE_TOKENS.RAW_C)

                    for i = 1, #exstr, 1 do
                        consume()
                    end

                    return true
                end
            end
        end

        if peek():match("[%a_]") then
            push_back(consume())
            while peek() and peek():match("[%w_]") do
                push_back(consume())
            end
            return false
        end

        if peek():match("#") and peek(1) and peek(1):match("[%a]") then
            push_back(consume())
            while peek() and peek():match("[%a]") do
                push_back(consume())
            end
            return false
        end

        if peek():match("#") then
            push_back(consume())
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

        if peek() and peek():match("[%-%+%*/%%]") then
            if peek():match("%-") and peek(1):match("%-") then
                push_back(consume())
                push_back(consume())
                while peek() and peek() ~= "\n" do
                    push_back(consume())
                end
                return false
            end

            if peek():match("%-") and peek(1):match(">") then
                consume()
                consume()
                new_token(buf, PRE_TOKENS.POINTER)
                buf = ""
                return true
            end

            if peek() == "/" and peek(1) == "/" then
                push_back(consume())
                push_back(consume())
                return false
            end

            push_back(consume())
            return false
        end

        if peek() and peek():match("[%(%{%[%)%}%];,%.:&]") then
            if peek() and peek():match(":") then
                push_back(consume())
                return false
            end
            push_back(consume())
            return false
        end

        if peek() and peek():match("[~=]") then
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
            error_gene(string.format("Invalid Token ; buffer['%s'] peek['%s']", buf, tostring(peek())))
        end

        buf = ""
    end

    for i, token in ipairs(tokens) do
        if not token.token then
            error_gene(string.format("error while generating tokens. Token don't have a 'token' key ; buffer['%s']",
                tostring(token.buf)))
        end

        if not token.buf then
            error_gene(string.format(
                "error_gene while generating tokens. Token '%s' don't have a valid buffer with info ; buffer['%s']",
                token.token, tostring(token.buf)))
        end
    end

    return tokens
end

return _M
