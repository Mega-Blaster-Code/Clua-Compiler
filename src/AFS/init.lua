local lexer = require("AFS/lexer")
local tokens = lexer.new(arg)

local vm = require("AFS/vm")
local ARGUMENTS, from_load = vm.new(tokens):start()

return ARGUMENTS