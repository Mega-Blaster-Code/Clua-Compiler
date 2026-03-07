local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")

local _M = {}

function _M.lower(ast)
    return ast
end

local prec = {
    ["||"] = 1,
    ["&&"] = 2,
    ["|"] = 3,
    ["^"] = 4,
    ["&"] = 5,
    ["=="] = 6,
    ["!="] = 6,
    ["<"] = 7,
    ["<="] = 7,
    [">"] = 7,
    [">="] = 7,
    ["<<"] = 8,
    [">>"] = 8,
    ["+"] = 9,
    ["-"] = 9,
    ["*"] = 10,
    ["/"] = 10,
    ["//"] = 10,
    ["%"] = 10
}

local AST_SPEC, KINDS

do
    local info = require("ASTkinds")
    AST_SPEC, KINDS = info[1], info[2]
end

local no_tab = false

local no_semicolan = false

local TABlevel = -1

local function genSemicolan()
	if no_semicolan then
		return ""
	end
	return ";"
end

local function genTab()
	if no_tab then
		return ""
	end
	local f = {}
	for i = 1, TABlevel do
		f[#f + 1] = "\t"
	end
	return table.concat(f)
end

local function push(buffer, str)
    buffer[#buffer + 1] = str
end

local function pushS(buffer, str)
    buffer[#buffer + 1] = str
    buffer[#buffer + 1] = " "
end

function _M.buildVarTypes(node)
    local line = {}

    local qualifiers = node.qualifiers
    local modifiers = node.modifiers

    if qualifiers.outside then
        pushS(line, "extern")
    end

    if qualifiers.static then
        pushS(line, "static")
    end

    if qualifiers.sign == "unsigned" then
        pushS(line, "unsigned")
    end

    if qualifiers.short then
        pushS(line, "short")
    end

    for i = 1, qualifiers.long_count do
        pushS(line, "long")
    end

    push(line, node.type)

    return table.concat(line)
end

function _M.buildDeclaratorInit(node, name)
	name = name or ""

	local line = {}

	pushS(line, _M.buildVarTypes(node))

	local modifiers = node.modifiers

	for i, mod in ipairs(modifiers) do
		if mod.kind == KINDS.POINTER_MODIFIER then
			if modifiers[i - 1] and modifiers[i - 1].kind == KINDS.ARRAY_MODIFIER then
				name = "(*" .. name .. ")"
			else
				name = "*" .. name
			end
		elseif mod.kind == KINDS.ARRAY_MODIFIER then
			name = name .. "["
			if mod.size then
				if not mod.runtime_size then
					name = name .. mod.size
				else
					local size = _M.buildExpression(mod.size)
					name = name .. size
				end
			end
			name = name  .. "]"
		end
	end

	push(line, name)

	return table.concat(line)
end

function _M.buildDeclarator(node)
    local line = {}

	local name = node.name or node.callee

	push(line, _M.buildDeclaratorInit(node, name))

    return table.concat(line)
end

function _M.buildExpression(node, parent_prec)
    parent_prec = parent_prec or 0
    if node.kind == KINDS.EXPRESSION then
        node = node.values
    end

    local expression = {}

    if node.kind == KINDS.BINARY_EXPRESSION then

        local op = node.op
        if op == "//" then
            op = "/"
        end
        local my_prec = prec[op]

        local left = _M.buildExpression(node.left, my_prec)

        local right = _M.buildExpression(node.right, my_prec)

        if my_prec < parent_prec then
            push(expression, "(")
            pushS(expression, left)
            pushS(expression, op)
            push(expression, right)
            push(expression, ")")
        else
            pushS(expression, left)
            pushS(expression, op)
            push(expression, right)
        end

    elseif node.kind == KINDS.CAST then
        local types = _M.buildDeclaratorInit(node.info)
        local value = _M.buildExpression(node.value, 12)

        push(expression, "(")
        push(expression, types)
        push(expression, ")")
        push(expression, value)
    elseif node.kind == KINDS.UNARY_EXPRESSION then

        local my_prec = 11
        local expr = node.expr

        local inner = _M.buildExpression(expr, my_prec)

        push(expression, "(")
        push(expression, node.op)
        push(expression, inner)
        push(expression, ")")
	
	elseif node.kind == KINDS.ADDRESS_OF then

        local my_prec = 11
        local expr = node.expr

        local inner = _M.buildExpression(expr, my_prec)

        push(expression, node.op)
        push(expression, inner)
	
	elseif node.kind == KINDS.POINTER_DEREFERENCE then

        local my_prec = 11
        local expr = node.expr

        local inner = _M.buildExpression(expr, my_prec)

        push(expression, "*(")
        push(expression, inner)
        push(expression, ")")

    elseif node.kind == KINDS.ARRAY then
		push(expression, "{")
		for i, val in ipairs(node.values) do
			push(expression, _M.buildExpression(val))
			if i ~= #node.values then
				pushS(expression, ",")
			end
		end

		push(expression, "}")

	elseif node.kind == KINDS.VAR_REF_FIELDS then

		local base = _M.buildExpression(node.base)

		push(expression, base)

		for i, op in ipairs(node.ops) do
			if op.kind == KINDS.INDEX_FIELD_ACCESS then
				push(expression, "[")
				push(expression, _M.buildExpression(op.index))
				push(expression, "]")
			end
		end

	elseif node.kind == KINDS.CALL_EXPRESSION then
		push(expression, node.callee)
		push(expression, "(")

		for i, arg in ipairs(node.args) do
			local expr = _M.buildExpression(arg)
			push(expression, expr)
			if i ~= #node.args then
				pushS(expression, ",")
			end
		end

		push(expression, ")")
    elseif node.kind == KINDS.VAR_REF then
        push(expression, node.name)
	elseif node.kind == KINDS.LITERAL_INT then
        push(expression, node.value)
    elseif node.kind == KINDS.LITERAL_FLOAT then
        push(expression, node.value)
    end

    return table.concat(expression)
end

function _M.buildVarDeclaration(node)
    local line = {}

	push(line, genTab())

    pushS(line, _M.buildDeclarator(node))

    pushS(line, "=")

    push(line, _M.buildExpression(node.values))

    push(line, genSemicolan())

    return table.concat(line)
end

function _M.buildVarPrototypeDeclaration(node)
    local line = {}

	push(line, genTab())

    push(line, _M.buildDeclarator(node))

    push(line, genSemicolan())

    return table.concat(line)
end

function _M.buildFunctionDeclaration(node)
	local line = {}

    push(line, _M.buildDeclarator(node))

    push(line, "(")

	for i, arg in ipairs(node.args) do
		push(line, _M.buildDeclarator(arg))
		if i ~= #node.args then
			pushS(line, ",")
		end
	end

	push(line, "){\n")

	push(line, _M.emitBlock(node.body))

	push(line, "\n}\n")

    return table.concat(line)
end

function _M.buildFunctionPrototypeDeclaration(node)
	local line = {}

    push(line, _M.buildDeclarator(node))

    push(line, "(")

	for i, arg in ipairs(node.args) do
		push(line, _M.buildDeclarator(arg))
		if i ~= #node.args then
			pushS(line, ",")
		end
	end

	push(line, ")")

	push(line, genSemicolan())

    return table.concat(line)
end

function _M.buildReturn(node)
	local line = {}

	push(line, genTab())

	pushS(line, "return")

	push(line, _M.buildExpression(node.values))

	push(line, genSemicolan())

	return table.concat(line)
end

function _M.buildVoidReturn(node)
	local line = {}

	push(line, genTab())

	push(line, "return")

	push(line, genSemicolan())

	return table.concat(line)
end

function _M.buildExtern(node)
	local line = {}

	push(line, node.raw)

	return table.concat(line)
end

function _M.buildVarAssignment(node)
	local line = {}

	local left = _M.buildExpression(node.lvalue)

	local right = _M.buildExpression(node.rvalue)

	push(line, genTab())

	pushS(line, left)

	pushS(line, "=")

	push(line, right)

	push(line, genSemicolan())

	return table.concat(line)
end

function _M.buildRawDo(node)
	local line = {}

	push(line, genTab())

	push(line, "{\n")

	push(line, _M.emitBlock(node.body))

	push(line, "\n")

	push(line, genTab())

	push(line, "}")

    return table.concat(line)
end

function _M.buildIf(node)
	local line = {}

	push(line, genTab())

    push(line, "if(")

	push(line, _M.buildExpression(node.condition))

	push(line, "){\n")

	push(line, _M.emitBlock(node.body))

	push(line, "\n")

	push(line, genTab())

	push(line, "}")

    return table.concat(line)
end

function _M.buildWhile(node)
	local line = {}

	push(line, genTab())

    push(line, "while(")

	push(line, _M.buildExpression(node.condition))

	push(line, "){\n")

	push(line, _M.emitBlock(node.body))

	push(line, "\n")

	push(line, genTab())

	push(line, "}")

    return table.concat(line)
end

function _M.buildFor(node)
	local line = {}

	push(line, genTab())

    push(line, "for(")

	no_tab = true
	no_semicolan = true

	push(line, _M.generate(node.init))

	push(line, ";")

	push(line, _M.generate(node.condition))

	push(line, ";")
	
	push(line, _M.generate(node.step))

	no_semicolan = false
	no_tab = false

	push(line, "){\n")

	push(line, _M.emitBlock(node.body))

	push(line, "\n")

	push(line, genTab())

	push(line, "}")

    return table.concat(line)
end

function _M.buildCall(node)
	local line = {}
	push(line, genTab())

	push(line, node.callee)
	push(line, "(")

	for i, arg in ipairs(node.args) do
		local expr = _M.buildExpression(arg)
		push(line, expr)
		if i ~= #node.args then
			pushS(line, ",")
		end
	end

	push(line, ")")

	push(line, genSemicolan())

	return table.concat(line)
end

function _M.buildBreak(node)
	return genTab() .. "break;"
end

local ANALYZER_BUILD = {
    [KINDS.FUNCTION_DECLARATION] = _M.buildFunctionDeclaration,
    [KINDS.FUNCTION_DECLARATION_PROTOTYPE] = _M.buildFunctionPrototypeDeclaration,
    [KINDS.VAR_ASSIGNMENT] = _M.buildVarAssignment,
    [KINDS.VAR_DECLARATION] = _M.buildVarDeclaration,
    [KINDS.VAR_DECLARATION_PROTOTYPE] = _M.buildVarPrototypeDeclaration,
    [KINDS.IF] = _M.buildIf,
    [KINDS.WHILE] = _M.buildWhile,
    [KINDS.FOR] = _M.buildFor,
    [KINDS.BREAK] = _M.buildBreak,
    [KINDS.RETURN] = _M.buildReturn,
    [KINDS.VOID_RETURN] = _M.buildVoidReturn,
    [KINDS.RAW_DO] = _M.buildRawDo,
    [KINDS.EXTERN] = _M.buildExtern,
	[KINDS.CALL_EXPRESSION] = _M.buildCall,
	[KINDS.EXPRESSION] = _M.buildExpression,
}

function _M.generate(node)
    local generator = ANALYZER_BUILD[node.kind]

    if not generator then
        error(string.format("Kind %s was unexpected", tostring(node.kind)))
    end

    return generator(node)
end

function _M.emitBlock(node)
	TABlevel = TABlevel + 1
    local code = {}
    for i, lnode in ipairs(node) do
        code[#code + 1] = _M.generate(lnode)
    end

	TABlevel = TABlevel - 1
    return table.concat(code, "\n")
end

function _M.emit(ast)
    local code = _M.emitBlock(ast.body)
    return code
end

return _M
