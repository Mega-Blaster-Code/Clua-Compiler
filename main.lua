local ARGUMENTS = require("AFS")

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

if type(ARGUMENTS:GET_FLAG("-f")) == "string" then
	file_path = ARGUMENTS:GET_FLAG("-f")
else
	ARGUMENTS:ERROR("No input file. " .. color8.sfcolor(50, 50, 50) .. "(use '-f' to define a input file)" .. color8.sfcolor(200, 200, 200))
end

local code_handler, err = file2io.open(file_path, file2io.modes.read_binary)
if not code_handler then
	ARGUMENTS:ERROR(err)
end

local content = code_handler:read()
code_handler:close()

content = content:gsub("\r\n", "\n")

local tokens = lexer.tokenize(file_path, content)
local preprocessor_directive = preprocessor.new(tokens, ARGUMENTS, file_path)

local _i = preprocessor_directive:start()

if type(ARGUMENTS:GET_FLAG("-pp")) == "string" then
	file_path = ARGUMENTS:GET_FLAG("-pp")
	local fpp = require("fpp")
	fpp(file_path, _i)
end

if type(ARGUMENTS:GET_FLAG("-PP")) == "boolean" then
	ARGUMENTS:clear_tmp()
	os.exit(0)
end

local ast_handler = parser.new(file_path, ARGUMENTS, _i)
local AST_TREE = ast_handler:start(true)

if type(ARGUMENTS:GET_FLAG("-ast")) == "string" then
	-- TODO: make the Table To Pointer script work
	local file_path = ARGUMENTS:GET_FLAG("-ast")
	local file_h = file2io.open(file_path, file2io.modes.write_binary)
	file_h:write(inspect(AST_TREE))
	file_h:close()
end

ARGUMENTS:clear_tmp()