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

function _M.analyzeExpression(node, expected, no_literal_array, prototype, original_node)
	local can, t, skip = expression.getExpression(node, false, no_literal_array, original_node)

    if expected then
        t = types.resolveLiteral(t, expected, node)
    else
        t = types.literalToBase(t)
    end

    if expected then
        local can, err = types.lowNumEquals(t, expected)
        if not can then
            _SEMANTIC.ARGUMENTS:ERROR(string.format("Expression don't match expected / %s", tostring(err),
                inspect(expected), inspect(t)))
        end
    end

    return true, t, skip
end

function _M.analyzeProgram(node)
    _M.analyzeBlock(node.body)
end

function _M.analyzeIf(node)

    _M.analyzeExpression(node.condition, nil, true)

    _M.analyzeBlock(node.body)

    if node._elseif then
        for i, lnode in ipairs(node._elseif) do
            _M.analyzeExpression(lnode.condition)
            _M.analyzeBlock(lnode.body)
        end
    end

    if node._else then
        _M.analyzeBlock(node._else.body)
    end
end

function _M.analyzeWhile(node)
    -- analyze expression

    _M.analyzeExpression(node.condition, nil, true)

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
    _M.analyzeExpression(node.condition, nil, true)

    _M.analyze(node.step)

    _M.analyzeLocalBlock(node.body)

    symbols.popScope()
end

function _M.analyzeBreak(node)
    local scope = symbols.ancestralScopeIs()

    if not scope or not scope.is_loop then
        _SEMANTIC.SERROR("Can't use 'break' outside a for or while loop", node)
    end

end

function _M.analyzeFunction(node)

    local t = types.build(node)
    local base = types.getBaseRoot(t)

    symbols.declareFunction(base.name, t)

    if base.prototype then
        return
    end

    local _scope = symbols.pushScope()
    _scope.is_function = t

    for i, lnode in ipairs(node.args) do
        _M.analyze(lnode, {fromInit = true})
    end

    _M.analyzeLocalBlock(node.body)

    symbols.popScope()

end

function _M.analyzeReturn(node)
    local scope = symbols.ancestralScopeIs()
    if not scope or not scope.is_function then
        _SEMANTIC.SERROR("Can't use 'return' outside a function", node)
    end

    local is_f = types.functionToBase(scope.is_function)

    if node.kind == KINDS.VOID_RETURN then
        if not types.isVoid(is_f) then
            _SEMANTIC.SERROR("Return type don't match return type of function", node)
        end
        scope.has_return = true
        return
    end

    local can, t = _M.analyzeExpression(node.values, nil, true)

    if not can then
        _SEMANTIC.SERROR("Invalid return expression", node)
    end

    if types.isVoid(is_f) then
        _SEMANTIC.SERROR("Void function can't return a value", node)
    end

    if not types.lowNumEquals(is_f, t) then
        _SEMANTIC.SERROR("Return type don't match return type of function", node)
    end

	local root = types.getBaseRoot(t)

	if types.isPointer(t) and not root.static and not root.fromInit then
		
		_SEMANTIC.SWARN("function is maybe returning a address of local variable", node)
	end

	local local_scope = symbols.getLocalScope()
    local_scope.has_return = true
end

function _M.analyzeDeclaration(node, info)
	info = info or {}
    local t = types.build(node)
    local base = types.getBaseRoot(t)

	base.fromInit = info.fromInit == true

    if node.kind == KINDS.VAR_DECLARATION then
        local can, t, skip = _M.analyzeExpression(node.values.values, t, nil, nil, node)
		t.temp = false
        if not can then
            _SEMANTIC.SERROR("Invalid expression", node)
        end
	end

	symbols.declareVariable(node.name, t)
end

function _M.analyzeRawDo(node)
    local _scope = symbols.pushScope()

    _M.analyzeLocalBlock(node.body)

    symbols.popScope()
end

function _M.analyzeAssignment(node)
    local l_value = node.lvalue
    local r_value = node.rvalue

    local can, t = _M.analyzeExpression(l_value, nil, false)
    _M.analyzeExpression(r_value, t)
end

function _M.analyzeExtern(node)

end

function _M.analyzeCallExpression(node)
    _M.analyzeExpression(node, nil, true)
end

function _M.analyzeIntern(node)
	_M.analyzeLocalBlock(node.body)
end

function _M.analyzeStructDeclaration(node, info)
	info = info or {}
    local t = types.build(node)
    local base = types.getBaseRoot(t)

	base.fromInit = info.fromInit == true

    symbols.declareStruct(node.name, t)
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
    [KINDS.RAW_DO] = _M.analyzeRawDo,
    [KINDS.PROGRAM] = _M.analyzeProgram,
    [KINDS.EXTERN] = _M.analyzeExtern,
    [KINDS.CALL_EXPRESSION] = _M.analyzeCallExpression,
	[KINDS.INTERN] = _M.analyzeIntern,
	[KINDS.STRUCT_DECLARATION] = _M.analyzeStructDeclaration,
	[KINDS.STRUCT_DECLARATION_PROTOTYPE] = _M.analyzeStructDeclaration,
}

function _M.analyze(node, info)
    operations = operations + 1

    local analyzer = ANALYZER_BUILD[node.kind]

    if not analyzer then
        _SEMANTIC.SERROR(string.format("Kind %s was unexpected", tostring(node.kind)), node)
    end

    analyzer(node, info)
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
