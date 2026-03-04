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
		local can_binary, result = _M.getBinary(t_left, t_right, node.op)

		if not can_binary then
			_SEMANTIC.ARGUMENTS:ERROR(string.format("Can't do binary operation [%s] with %s[%s] %s[%s]", node.op,
				t_left.type, t_left.kind, t_right.type, t_right.kind))
		end

		return true, result
	elseif node.kind == KINDS.UNARY_EXPRESSION or node.kind == KINDS.ADDRESS_OF then
		local can, t = _M.getExpression(node.expr)
		local op = node.op

		if op == "&" then
			if types.isTemp(t) then
				_SEMANTIC.ARGUMENTS:ERROR("Can't get address of a temporary value")
			end
		end
		
		return can, t
	elseif node.kind == KINDS.ARRAY then
		local size = #node.values

		if size == 0 then
			_SEMANTIC.ERROR("Empty array literal not allowed")
		end

		local _, first_type = _M.getExpression(node.values[1])

		for i = 2, size do
			local _, t = _M.getExpression(node.values[i])

			if not types.lowNumEquals(first_type, t) then
				_SEMANTIC.ERROR("Array literal element type mismatch")
			end
		end

		local final_type = types.array(first_type)
		final_type.size = size

		return true, final_type
	elseif node.kind == KINDS.VAR_REF_FIELDS then
		local _, base = _M.getExpression(node.base)
		local lbase = base
		for i, op in ipairs(node.ops) do
			if op.kind == KINDS.INDEX_FIELD_ACCESS then
				if not types.isArray(lbase) then
					_SEMANTIC.ARGUMENTS:ERROR("Can't index a non array values")
				end
				_M.getExpression(op.index)
				lbase = lbase.of
			end
		end

		return true, lbase
	elseif node.kind == KINDS.CAST then
		local value = node.value
		local info = node.info
		
		local type_t = types.build(info)
		local can, value_t = _M.getExpression(value)

		value_t = types.literalToBase(value_t)

		-- print(inspect(type_t), inspect(type_t))

		local can_cast, result = types.canCast(value_t, type_t)

		if not can_cast then
			_SEMANTIC.ARGUMENTS:ERROR(string.format("illegal casting with %s[%s] %s[%s]", type_t.type, type_t.kind,
				value_t.type, value_t.kind))
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

	return true, t
end

return _M
