local arguments = require("arguments")

local flags = arguments(arg)

local PRE_TOKENS, KEYWORDS

do
    local info = require("tokens")
    PRE_TOKENS, KEYWORDS = info[1], info[2]
end

local inspect = require("inspect")
local file2io = require("file2io")
local color8 = require("color8")

local preprocessor = require("preprocessor")
local lexer = require("lexer")
local parser = require("parser")

local file_path = "main.clua"

if flags.f then
	file_path = flags.f[1]
end

local code_handler = file2io.open(file_path, file2io.modes.read_binary)
local content = code_handler:read()
code_handler:close()

content = content:gsub("\r\n", "\n")

local tokens = lexer.tokenize(file_path, content)
local preprocessor_directive = preprocessor.new(tokens)

local _i = preprocessor_directive:start()

if flags.pp then
	local fpp = require("fpp")
	fpp(flags.pp, _i)
end

if flags.PP then
	os.exit(0)
end

local ast = parser.new(file_path, _i)
ast:start(true)