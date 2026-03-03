local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")

local operations = 0

local AST_SPEC, KINDS

do
    local info = require("ASTkinds")
    AST_SPEC, KINDS = info[1], info[2]
end

local DECLARATIONS_KINDS = {
    [KINDS.FUNCTION_DECLARATION_PROTOTYPE] = true,
    [KINDS.FUNCTION_DECLARATION] = true,
    [KINDS.STRUCT_DECLARATION_PROTOTYPE] = true,
    [KINDS.STRUCT_DECLARATION] = true,
    [KINDS.FUNCTION_DECLARATION_PROTOTYPE] = true,
    [KINDS.FUNCTION_DECLARATION] = true,
    [KINDS.VAR_DECLARATION_PROTOTYPE] = true,
    [KINDS.VAR_DECLARATION] = true,
    [KINDS.STRUCT_VAR_DECLARATION] = true,
    [KINDS.STRUCT_INIT_VAR_DECLARATION] = true
}

local STRUCT_DECLARATIONS_KINDS = {
    [KINDS.STRUCT_DECLARATION_PROTOTYPE] = true,
    [KINDS.STRUCT_DECLARATION] = true,
    [KINDS.STRUCT_VAR_DECLARATION] = true,
    [KINDS.STRUCT_INIT_VAR_DECLARATION] = true
}

local VAR_DECLARATIONS_KINDS = {
    [KINDS.FUNCTION_DECLARATION_PROTOTYPE] = true,
    [KINDS.FUNCTION_DECLARATION] = true,
    [KINDS.VAR_DECLARATION_PROTOTYPE] = true,
    [KINDS.VAR_DECLARATION] = true,
    [KINDS.STRUCT_VAR_DECLARATION] = true,
    [KINDS.STRUCT_INIT_VAR_DECLARATION] = true
}

local FUNCTION_DECLARATIONS_KINDS = {
    [KINDS.FUNCTION_DECLARATION_PROTOTYPE] = true,
    [KINDS.FUNCTION_DECLARATION] = true
}

local _SEMANTIC = _SEMANTIC

local types = require("semantic.types")
local symbols = require("semantic.symbols")

local _M = {}

function _M.analyzeIf(node)
    print("IF")
    -- analyze expression

    _M.analyzeBlock(node)

    if node._elseif then
        for i, lnode in ipairs(node._elseif) do
            -- analyze expression
            _M.analyzeBlock(lnode)
        end
    end

    if node._else then
        _M.analyzeBlock(node._else)
    end
end

function _M.analyzeWhile(node)
    -- analyze expression

    _M.analyzeBlock(node, "WHI" .. operations)
end

function _M.analyzeFor(node)
	
	symbols.pushScope(nil, "FOR" .. operations)
	
	_M.analyze(node.init)

	-- analyze expression

	_M.analyze(node.step)

	_M.analyzeLocalBlock(node)

	symbols.popScope()
end

function _M.analyzeBreak(node)
	local local_scope = symbols.getLocalScope()

	local name_sub = local_scope.name:sub(1, 3)

	if name_sub ~= "FOR" and name_sub ~= "WHI" then
		_SEMANTIC.ARGUMENTS:ERROR("Can't use 'break' outside a for or while loop")
	end
end

function _M.analyzeFunction(node)
	
	local t = types.build(node)
	local base = types.getBaseRoot(t)

	if base.prototype then
		return
	end

	symbols.declareFunction(base.name, t)
	
    print("FUNCTION", base.name)
	
	print(inspect(base))

	symbols.pushScope(nil, "FUN" .. operations)

	for i, lnode in ipairs(node.args) do
		_M.analyze(lnode)
	end

	-- analyze expression

	_M.analyzeLocalBlock(node)

	symbols.popScope()

end

function _M.analyzeDeclaration(node)
    local t = types.build(node)
	local base = types.getBaseRoot(t)
    print("VAR", base.name)
    symbols.declareVariable(base.name, t)
end

function _M.analyzeAssignment(node)
	local var = symbols.findVariable(node.name)
end

local ANALYZER_BUILD = {
	[KINDS.FUNCTION_DECLARATION] = _M.analyzeFunction,
	[KINDS.FUNCTION_DECLARATION_PROTOTYPE] = _M.analyzeFunction,
	[KINDS.VAR_ASSIGNMENT] = _M.analyzeAssignment,
    [KINDS.VAR_DECLARATION] = _M.analyzeDeclaration,
    [KINDS.VAR_DECLARATION_PROTOTYPE] = _M.analyzeDeclaration,
    [KINDS.IF] = _M.analyzeIf,
    [KINDS.WHILE] = _M.analyzeWhile,
	[KINDS.FOR] = _M.analyzeFor,
	[KINDS.BREAK] = _M.analyzeBreak,
}

function _M.analyze(node)
	operations = operations + 1
    print(node.kind)

    local analyzer = ANALYZER_BUILD[node.kind]

    analyzer(node)
end

function _M.analyzeLocalBlock(node)
	for i, lnode in ipairs(node.body) do
        _M.analyze(lnode)
        if i ~= #node.body then
            print("=====")
        end
    end
end

function _M.analyzeBlock(node, name) -- base
    symbols.pushScope(nil, name)

    _M.analyzeLocalBlock(node)

    symbols.popScope()
end

return _M
