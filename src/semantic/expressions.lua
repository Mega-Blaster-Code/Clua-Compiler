local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")

local operations = 0

local TKINDS = {
    BASE = "_T_BASE",
    POINTER = "_T_POINTER",
    ARRAY = "_T_ARRAY",
    STRUCT = "_T_STRUCT",
    FUNCTION = "_T_FUNCTION",
    LITERAL = "_T_LITERAL"
}


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

local function getStruct(name)
	local var = symbols.findStruct(name)

	if not var then
		_SEMANTIC.SERROR(string.format("Variable \"%s\" was not declared", name))
	end

	return var
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

function _M.getExpression(node, no_cast, no_literal_array, original_node)
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
			if types.isTemp(t) and not types.getBaseRoot(t).name then
				_SEMANTIC.SERROR("Can't get address of a temporary value", node)
			end
		end

		t = types.pointer(t)

		t.temp = true
		
		return true, t
	elseif node.kind == KINDS.POINTER_DEREFERENCE then
		local can, t = _M.getExpression(node.expr, no_cast, no_literal_array)
		local op = node.op

		if types.isTemp(t) then
			_SEMANTIC.SERROR("Can't dereference a temporary values", node)
		end

		if not types.isPointer(t) then
			_SEMANTIC.SERROR("Can't dereference a non pointer value", node)
		end

		t = types.dereference(t)
		
		return true, t
	elseif node.kind == KINDS.ARRAY then
		if no_literal_array then
			_SEMANTIC.SERROR("Literal array is not allow here", node)
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

		return true, final_type
	elseif node.kind == KINDS.VAR_REF_FIELDS then
		local _, base = _M.getExpression(node.base, no_cast, no_literal_array)
		local lbase = base
		for i, op in ipairs(node.ops) do
			if op.kind == KINDS.INDEX_FIELD_ACCESS then
				if not types.isArray(lbase) and not types.isPointer(lbase) then
					_SEMANTIC.SERROR("Can't index a non array/pointer values", node)
				end

				_M.getExpression(op.index, no_cast, no_literal_array)

				if types.isPointer(lbase) then
					lbase = lbase.to
				else
					lbase = lbase.of
				end
			elseif op.kind == KINDS.FIELD_ACCESS then
				if not types.isStruct(lbase) then
					_SEMANTIC.SERROR("Can't access field of a non struct value", node)
				end

				local struct = getStruct(lbase.type)

				if not struct.fields[op.name] then
					_SEMANTIC.SERROR(string.format("Field \"%s\" in struct \"%s\" don't exist", op.name, struct.type), node)
				end
				lbase = struct.fields[op.name]
			elseif op.kind == KINDS.POINTER_FIELD_ACCESS then	

				if not types.isPointer(lbase) then
					_SEMANTIC.SERROR(string.format("struct is not a pointer"), node)
				end

				if not types.isStruct(lbase.to) then
					_SEMANTIC.SERROR("Can't access pointer field of a non struct value", node)
				end

				local struct = getStruct(lbase.to.type)
				
				if not struct.fields[op.name] then
					_SEMANTIC.SERROR(string.format("Pointer Field \"%s\" in struct \"%s\" don't exist", op.name, struct.type), node)
				end

				local dest = struct.fields[op.name]

				lbase = struct.fields[op.name]
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

		local can_cast, err = types.canCast(value_t, type_t)

		if not can_cast then
			_SEMANTIC.SERROR(string.format("illegal casting with %s[%s] %s[%s]; %s", types.getBaseRoot(type_t).type, types.getBaseRoot(type_t).kind,
				types.getBaseRoot(value_t).type, types.getBaseRoot(value_t).kind, err), node)
		end

		return true, type_t
	elseif node.kind == KINDS.CALL_EXPRESSION then
		local func = getFunction(node.callee)
		local in_args = {}

		for i, arg in ipairs(node.args) do
			local _, t = _M.getExpression(arg, no_cast, no_literal_array)
			in_args[i] = t
		end

		local root = types.getBaseRoot(func)

		if #in_args > #root.args then
			_SEMANTIC.SERROR(string.format("Function Call has too many arguments. expected %d got %d", #func.args, #in_args), node)
		end

		for i, arg in ipairs(root.args) do
			if not in_args[i] then
				_SEMANTIC.SERROR(string.format("Function Call is missing %d arguments. missing in #%d", #func.args - (i - 1), i), node)
			end
			local equal, err = types.equals(in_args[i], arg)
			if not equal then
				_SEMANTIC.SERROR(string.format("Function Call arguments don't match declaration %s\n%s[%s] != %s[%s]",err ,types.getBaseRoot(in_args[i]).type, types.getBaseRoot(in_args[i]).kind, types.getBaseRoot(arg).type, types.getBaseRoot(arg).kind), node)
			end
		end

		return true, types.functionToBase(func)
	elseif node.kind == KINDS.STRUCT_INIT then
		local struct = getStruct(original_node.type)
		struct.type = original_node.type

		if struct.prototype then
			_SEMANTIC.SERROR(string.format("Struct \"%s\" is a prototype", original_node.type), node)
		end

		for i, var in ipairs(node.values) do
			if not struct.fields[var.name] then
				_SEMANTIC.SERROR(string.format("Field \"%s\" in struct \"%s\" don't exist", var.name, original_node.type), node)
			end
			local field = struct.fields[var.name]

			if field.filled then
				_SEMANTIC.SERROR(string.format("Field \"%s\" in struct \"%s\" is already filled", var.name, original_node.type), node)
			end

			local can, t = _M.getExpression(var.value, nil, true, node)

			if not types.lowNumEquals(field, t) then
				_SEMANTIC.SERROR(string.format("Field \"%s\" in struct \"%s\" don't match declaration", var.name, original_node.type), node)
			end

			field.filled = true
		end

		for i, var in pairs(struct.fields) do
			if not var.filled then
				_SEMANTIC.SWARN(string.format("Field \"%s\" in struct \"%s\" is not filled", var.name, original_node.type), node)
			end
			var.filled = false
		end

		return true, struct, true
	elseif node.kind == KINDS.LITERAL_STRING then
		local base = types.base({type = "char", name = string.format("__string_%d%d%d", math.random(0, 99999999), math.random(0, 99999999), math.random(0, 99999999))}, 1, "unsigned", false, false, false)
		local t = types.pointer(base)
		return true, t
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
