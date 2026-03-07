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
		_SEMANTIC.SERROR(string.format("Variable \"%s\" was not declared", name))
	end

	return var
end

local function getFunction(name)
	local fuc = symbols.findFunction(name)

	if not fuc then
		_SEMANTIC.SERROR(string.format("Function \"%s\" was not declared", name))
	end

	return fuc
end

function _M.getBinary(tA, tB, op)
	local can_binary, result = types.binary(op, tA, tB)

	return can_binary, result
end

function _M.getExpression(node, no_cast, no_literal_array)
	if node.kind == KINDS.BINARY_EXPRESSION then
		local left = node.left
		local right = node.right

		local can_left, t_left = _M.getExpression(left, no_cast, no_literal_array)

		local can_right, t_right = _M.getExpression(right, no_cast, no_literal_array)
		local can_binary, result = _M.getBinary(t_left, t_right, node.op)

		if not can_binary then
			_SEMANTIC.SERROR(string.format("Can't do binary operation [%s] with %s[%s] %s[%s]", node.op,
				t_left.type, t_left.kind, t_right.type, t_right.kind), node)
		end

		return true, result
	elseif node.kind == KINDS.UNARY_EXPRESSION or node.kind == KINDS.ADDRESS_OF then
		local can, t = _M.getExpression(node.expr, no_cast, no_literal_array)
		local op = node.op

		if op == "&" then
			if types.isTemp(t) then
				_SEMANTIC.SERROR("Can't get address of a temporary value", node)
			end
		end
		
		return can, t
	elseif node.kind == KINDS.ARRAY then
		if no_literal_array then
			_SEMANTIC.SERROR("Literal array is not allow here")
		end

		local size = #node.values

		if size == 0 then
			_SEMANTIC.SERROR("Empty array literal not allowed", node)
		end

		local _, first_type = _M.getExpression(node.values[1], no_cast, no_literal_array)

		for i = 2, size do
			local _, t = _M.getExpression(node.values[i], no_cast, no_literal_array)

			if not types.lowNumEquals(first_type, t) then
				_SEMANTIC.SERROR("Array literal element type mismatch", node)
			end
		end

		local final_type = types.array(first_type)
		final_type.size = size
		final_type.runtime_size = false
		final_type.compile_time_size = true
		print(final_type.size)

		return true, final_type
	elseif node.kind == KINDS.VAR_REF_FIELDS then
		local _, base = _M.getExpression(node.base, no_cast, no_literal_array)
		local lbase = base
		for i, op in ipairs(node.ops) do
			if op.kind == KINDS.INDEX_FIELD_ACCESS then
				if not types.isArray(lbase) then
					_SEMANTIC.SERROR("Can't index a non array values", node)
				end
				_M.getExpression(op.index, no_cast, no_literal_array)
				lbase = lbase.of
			end
		end

		return true, lbase
	elseif node.kind == KINDS.CAST then
		if no_cast then
			_SEMANTIC.SERROR(string.format("illegal casting"), node)
		end
		local value = node.value
		local info = node.info
		
		local type_t = types.build(info)
		local can, value_t = _M.getExpression(value, no_cast, no_literal_array)

		value_t = types.literalToBase(value_t)

		local can_cast, result = types.canCast(value_t, type_t)

		if not can_cast then
			_SEMANTIC.SERROR(string.format("illegal casting with %s %s[%s] %s[%s]", result, type_t.type, type_t.kind,
				value_t.type, value_t.kind), node)
		end

		return true, type_t
	elseif node.kind == KINDS.CALL_EXPRESSION then
		local func = getFunction(node.callee)
		local in_args = {}

		for i, arg in ipairs(node.args) do
			local _, t = _M.getExpression(arg, no_cast, no_literal_array)
			in_args[i] = t
		end

		if #in_args > #func.args then
			_SEMANTIC.SERROR(string.format("Function Call has too many arguments. expected %d got %d", #func.args, #in_args), node)
		end

		for i, arg in ipairs(func.args) do
			if not in_args[i] then
				_SEMANTIC.SERROR(string.format("Function Call is missing %d arguments. missing in #%d", #func.args - (i - 1), i), node)
			end
			if not types.equals(in_args[i], arg) then
				_SEMANTIC.SERROR(string.format("Function Call arguments don't match declaration\n%s[%s] != %s[%s]", in_args[i].type, in_args[i].kind, arg.type, arg.kind), node)
			end
		end

		return true, types.functionToBase(func)
	end

	local _, t

	if _M.isLiteral(node) then
		t = types.build(node)
	elseif _M.isExpression(node) then
		_, t = _M.getExpression(node.values, no_cast, no_literal_array)
	elseif _M.isVarRef(node) then
		t = getVariable(node.name)
	end

	return true, t
end

return _M
