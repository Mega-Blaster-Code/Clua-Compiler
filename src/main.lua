local src = debug.getinfo(1, "S").source:sub(2)
src = src:match("(.*/)")


package.path = src .. "?.lua;" .. src .. "?/init.lua;" .. src .. "src/?.lua;" .. src .. "src/semantic/?.lua;" .. src .. "src/codeGeneration/?.lua;" .. src .. "semantic/?.lua;" .. src .. "codeGeneration/?.lua;" .. package.path


local ARGUMENTS = require("AFS")

local PRE_TOKENS, KEYWORDS

do
    local info = require("tokens")
    PRE_TOKENS, KEYWORDS = info[1], info[2]
end


local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")


local preprocessor = require("preprocessor")
local lexer = require("lexer")
local parser = require("parser")
local semantic = require("semantic")
local codeGen = require("codeGeneration")

local file_path = "main.clua"


if type(ARGUMENTS:GET_FLAG("-f")) == "string" then
    file_path = ARGUMENTS:GET_FLAG("-f")
else
    ARGUMENTS:ERROR("No input file. " .. color8.sfcolor(50, 50, 50) .. "(use '-f' to define a input file)" ..
                        color8.sreset())
end

local code_handler, err = file2io.open(file_path, file2io.modes.read_binary)
if not code_handler then
    ARGUMENTS:ERROR(err)
end

local content = code_handler:read()
code_handler:close()


local tokenezer = lexer.new(file_path, content, ARGUMENTS)
local tokens = tokenezer:start()

if type(ARGUMENTS:GET_FLAG("-tt")) == "string" then
    local file_path = ARGUMENTS:GET_FLAG("-tt")
    local fpp = require("fpp")
    fpp(file_path, tokens)
end

if type(ARGUMENTS:GET_FLAG("-TT")) == "boolean" then
    os.exit(0)
end


local preprocessor_directive = preprocessor.new(tokens, ARGUMENTS, file_path)

local _i = preprocessor_directive:start()

if type(ARGUMENTS:GET_FLAG("-pp")) == "string" then
    local file_path = ARGUMENTS:GET_FLAG("-pp")
    local fpp = require("fpp")
    fpp(file_path, _i)
end

if type(ARGUMENTS:GET_FLAG("-PP")) == "boolean" then
    os.exit(0)
end


local ast_handler = parser.new(file_path, ARGUMENTS, _i)
local AST_TREE = ast_handler:start(not ARGUMENTS:GET_FLAG("-no-semicolan"))
local clean_AST_TREE = parser.clean(AST_TREE)

if type(ARGUMENTS:GET_FLAG("-ast")) == "string" then
    local file_path = ARGUMENTS:GET_FLAG("-ast")
    local file_h = file2io.open(file_path, file2io.modes.write_binary)
    file_h:write(inspect(clean_AST_TREE))
    file_h:close()
end

if type(ARGUMENTS:GET_FLAG("-SS")) == "boolean" then
    os.exit(0)
end


local semantic_handler = semantic.new(file_path, AST_TREE, ARGUMENTS)
semantic_handler:start()


codeGen.load(ARGUMENTS)

local output_file = nil

local target = "c"

if type(ARGUMENTS:GET_FLAG("-target")) == "string" then
    target = ARGUMENTS:GET_FLAG("-target")
end

if type(ARGUMENTS:GET_FLAG("-o")) == "string" then
    output_file = ARGUMENTS:GET_FLAG("-o")
end

local codeGen_handler = codeGen.new(output_file, target, AST_TREE, ARGUMENTS)
local out_content = codeGen_handler:start()

local output_file_handler = file2io.open(output_file or ("out." .. target), "wb")
output_file_handler:write(out_content)
output_file_handler:close()

io.stderr:write(string.format("%sSUCESS%s  compiled to file %s\"%s\"%s [%s%s%s]\n", color8.sfcolor(0, 255, 50),
    color8.sreset(), color8.sfcolor(100, 150, 255), output_file, color8.sreset(), color8.sfcolor(255, 100, 255), target,
    color8.sreset()))
