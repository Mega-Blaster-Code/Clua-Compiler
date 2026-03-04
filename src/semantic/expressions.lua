local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")

local operations = 0

local AST_SPEC, KINDS

do
    local info = require("ASTkinds")
    AST_SPEC, KINDS = info[1], info[2]
end

local _SEMANTIC = _SEMANTIC

local types = require("semantic.types")
local symbols = require("semantic.symbols")

local _M = {}

function _M.isLiteral(node)
    return node.kind == KINDS.LITERAL_INT or node.kind == KINDS.LITERAL_FLOAT
end

function _M.isExpression(node)
    return node.kind == KINDS.EXPRESSION
end

function _M.isVarRef(node)
    return node.kind == KINDS.VAR_REF
end

local function getVariable(name)
    local var = symbols.findVariable(name)

    if not var then
        _SEMANTIC.ARGUMENTS:ERROR(string.format("Variable \"%s\" was not declared", name))
    end

    return var
end

function _M.getBinary(tA, tB, op)
    local can_binary, result = types.binary(op, tA, tB)

    return can_binary, result
end

function _M.getExpression(node)
    if node.kind == KINDS.BINARY_EXPRESSION then
        local left = node.left
        local right = node.right

        local can_left, t_left = _M.getExpression(left)

        local can_right, t_right = _M.getExpression(right)

		print(can_left, can_right, inspect(t_left), inspect(t_right))

        local can_binary, result = _M.getBinary(t_left, t_right, node.op)

        if not can_binary then
            _SEMANTIC.ARGUMENTS:ERROR(string.format("Can't do binary operation [%s] with %s[%s] %s[%s]", node.op, t_left.type, t_left.kind, t_right.type, t_right.kind))
        end

		print("=====================")

        return true, result
    elseif node.kind == KINDS.CAST then
		local value = node.value
		local info = node.info
		--print("CASTING")
		local type_t = types.build(info)
		local can, value_t = _M.getExpression(value)

		--print(inspect(type_t), inspect(type_t))

		local can_cast, result = types.canCast(value_t, type_t)

		if not can_cast then
			_SEMANTIC.ARGUMENTS:ERROR(string.format("illegal casting with %s[%s] %s[%s]", type_t.type, type_t.kind, value_t.type, value_t.kind))
		end
		
		return true, type_t
	end

    local _, t

    if _M.isLiteral(node) then
        t = types.build(node)
    elseif _M.isExpression(node) then
        _, t = _M.getExpression(node.values)
    elseif _M.isVarRef(node) then
        t = getVariable(node.name)
    end

	print("LEAF",inspect(t))

    return true, t
end

return _M
