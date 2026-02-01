local PRE_TOKENS, KEYWORDS

do
    local info = require("tokens")
    PRE_TOKENS, KEYWORDS = info[1], info[2]
end

local file2io = require("file2io")

local function start(file_name, tokens)
    local handler = file2io.open(file_name, file2io.modes.write_binary)

	

    local out = {}

    for i, token in ipairs(tokens) do
        local t = token.token

        if t == PRE_TOKENS.NEW_LINE then
			if #out == 0 then
				goto continue
			end
            out[#out + 1] = "\n"
            goto continue
        end

        local quote = ""
        if t == PRE_TOKENS.STRING_LITERAL then
            quote = '"'
        elseif t == PRE_TOKENS.CHAR_LITERAL then
            quote = "'"
        end

        out[#out + 1] = quote .. token.buf .. quote

        local next_token = tokens[i + 1]
        if next_token then
            local nt = next_token.token

            if nt ~= PRE_TOKENS.NEW_LINE and
               t  ~= PRE_TOKENS.TAB then
                out[#out + 1] = " "
            end
        end

        ::continue::
    end

    handler:write(table.concat(out))
    handler:close()
end

return start
