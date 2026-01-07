local inspect = require("inspect")
local file2io = require("file2io")
local color8 = require("color8")

local lexer = require("lexer")
local parser = require("parser")

local code_handler = file2io.open("code.clua", file2io.modes.read_binary)
local content = code_handler:read()
code_handler:close()

local tokens = lexer.tokenize(content)
local ast    = parser.parse(tokens)
--print(content)