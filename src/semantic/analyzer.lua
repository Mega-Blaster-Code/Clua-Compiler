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
local expression = require("semantic.expressions")

local _M = {}

function _M.analyzeProgram(node)
	_M.analyzeBlock(node.body)
end

function _M.analyzeIf(node)

    _M.analyzeBlock(node.body)

    if node._elseif then
        for i, lnode in ipairs(node._elseif) do
            _M.analyzeBlock(lnode.body)
        end
    end

    if node._else then
        _M.analyzeBlock(node._else.body)
    end
end

function _M.analyzeWhile(node)
    -- analyze expression

    local _scope = symbols.pushScope()
	_scope.is_loop = true

	_M.analyzeLocalBlock(node.body)

	symbols.popScope()
end

function _M.analyzeFor(node)
	
	local _scope = symbols.pushScope()
	_scope.is_loop = true
	
	_M.analyze(node.init)

	-- analyze expression

	_M.analyze(node.step)

	_M.analyzeLocalBlock(node.body)

	symbols.popScope()
end

function _M.analyzeBreak(node)
	local scope = symbols.ancestralScopeIs()

	if not scope or not scope.is_loop then
		_SEMANTIC.ARGUMENTS:ERROR("Can't use 'break' outside a for or while loop")
	end

	print(scope.is_loop, inspect(scope))
end

function _M.analyzeFunction(node)
	
	local t = types.build(node)
	local base = types.getBaseRoot(t)

	symbols.declareFunction(base.name, t)

	if base.prototype then
		return
	end

    print("FUNCTION", base.name)
	
	print(inspect(base))

	local _scope = symbols.pushScope()
	_scope.is_function = true

	for i, lnode in ipairs(node.args) do
		_M.analyze(lnode)
	end

	-- analyze expression

	_M.analyzeLocalBlock(node.body)

	symbols.popScope()

end

function _M.analyzeReturn(node)
	local scope = symbols.ancestralScopeIs()
	if not scope or not scope.is_function then
		_SEMANTIC.ARGUMENTS:ERROR("Can't use 'return' outside a function")
	end
end

function _M.analyzeDeclaration(node)
    local t = types.build(node)
	local base = types.getBaseRoot(t)
    print("VAR", base.name)

	-- analyze expression

	if not expression.getExpression(node.values.values) then
		_SEMANTIC.ARGUMENTS:ERROR("Invalid expression")
	end

    symbols.declareVariable(base.name, t)
end

function _M.analyzeAssignment(node)
	local l_value
	local r_value
	--local var = symbols.findVariable(node.name)

	--if not var then
	--	_SEMANTIC.ARGUMENTS:ERROR("Can't assign to a undeclared variable")
	--end
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
	[KINDS.RETURN] = _M.analyzeReturn,
	[KINDS.VOID_RETURN] = _M.analyzeReturn,
	[KINDS.PROGRAM] = _M.analyzeProgram,
}

function _M.analyze(node)
	operations = operations + 1
    print(node.kind)

    local analyzer = ANALYZER_BUILD[node.kind]

	if not analyzer then
		_SEMANTIC.ARGUMENTS:ERROR(string.format("Kind %s was unexpected", tostring(node.kind)))
	end

	print("=====================")

    analyzer(node)
end

function _M.analyzeLocalBlock(node)
	for i, lnode in ipairs(node) do
        _M.analyze(lnode)
        if i ~= #node then

        end
    end
end

function _M.analyzeBlock(node, name) -- base
    symbols.pushScope(nil, name)

    _M.analyzeLocalBlock(node)

    symbols.popScope()
end

return _M
