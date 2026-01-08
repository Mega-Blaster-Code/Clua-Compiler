local inspect = require("inspect")
local file2io = require("file2io")
local color8 = require("color8")

local lexer = require("lexer")
local parser = require("parser")

local file_path = "code.clua"

local code_handler = file2io.open(file_path, file2io.modes.read_binary)
local content = code_handler:read()
code_handler:close()

local tokens = lexer.tokenize(file_path, content)
local ast    = parser.new(file_path, tokens)
ast:start(true)
--print(content)