local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")

local AST_SPEC, KINDS

do
    local info = require("ASTkinds")
    AST_SPEC, KINDS = info[1], info[2]
end

local __SEMANTIC = _SEMANTIC
local _M = {}


local NUMERIC_SHORT = 0
local NUMERIC_LONG = 1
local NUMERIC_LONGLONG = 2
local NUMERIC_DEFAULT = 3

local POINTER_SIZE = 8

local types_to_kinds = {
    ["int"] = {KINDS.LITERAL_INT},
    ["float"] = {KINDS.LITERAL_FLOAT},
    ["double"] = {KINDS.LITERAL_FLOAT},
    ["char"] = {KINDS.LITERAL_CHAR, KINDS.LITERAL_INT}
}

local types_sizes = {
	["char"] = {
		[NUMERIC_DEFAULT] = 1,
	},
    ["int"] = {
		[NUMERIC_SHORT] = 2,
		[NUMERIC_DEFAULT] = 4,
		[NUMERIC_LONG] = 8,
		[NUMERIC_LONGLONG] = 8,
	},
	["float"] = {
		[NUMERIC_DEFAULT] = 4,
	},
	["double"] = {
		[NUMERIC_DEFAULT] = 8,
		[NUMERIC_LONG] = 8,
	},
	["void"] = {
		[NUMERIC_DEFAULT] = 8,
	}
}

local TKINDS = {
	BASE = "_T_BASE",
	POINTER = "_T_POINTER",
	ARRAY = "_T_ARRAY",
	STRUCT = "_T_STRUCT",
	FUNCTION = "_T_FUNCTION",
}

function _M.isNumeric(var)
    return (var.type == "int" or var.type == "float" or var.type == "double" or var.type == "char")
end

function _M.getNumeric(var)
	if not _M.isNumeric(var) then
    	return nil
	end
	local quali = var.qualifiers
	if quali.is_short then
		return NUMERIC_SHORT
	end

	if quali.long_count > 0 then
		if quali.long_count == 1 then
			return NUMERIC_LONG
		end
		return NUMERIC_LONGLONG
	end
	return NUMERIC_DEFAULT
end

function _M.base(var, numeric, sign)
	return {
		kind = TKINDS.BASE,
		type = var.type,
		numeric = numeric,
		volatile = false,
		sign = sign,
		const = false,
		name = var.name,
	}
end

function _M.pointer(inner)
	return {
		kind = TKINDS.POINTER,
		const = false,
		volatile = false,
		to = inner,
	}
end

function _M.array(inner)
	return {
		kind = TKINDS.ARRAY,
		const = false,
		volatile = false,
		size = 0,
		of = inner,
	}
end

function _M.struct(var)
	return {
		kind = TKINDS.STRUCT,
		fields = var.values.values,
	}
end

function _M._function(var)
	local b = _M.base(var, _M.getNumeric(var), var.qualifiers.sign)
	local t = {
		kind = TKINDS.FUNCTION,
		type = var.type,
		numeric = b.numeric,
		volatile = b.volatile,
		sign = b.sign,
		const = b.const,
		name = var.callee,
		prototype = false,
		args = {}
	}

	for i, v in ipairs(var.args) do
		t.args[i] = _M.build(v)
	end


	return t
end

function _M.const(inner)
	inner.const = true
end

function _M.volatile(inner)
	inner.volatile = true
end

function _M.build(var)
	local modifiers = var.modifiers
	local qualifiers = var.qualifiers

	local t

	if var.kind == KINDS.FUNCTION_DECLARATION then
		t = _M._function(var)
		t.prototype = false
	elseif var.kind == KINDS.FUNCTION_DECLARATION_PROTOTYPE then
		t = _M._function(var)
		t.prototype = true
	else
		t = _M.base(var, _M.getNumeric(var), qualifiers.sign)
	end

	for i = #var.modifiers, 1, -1 do
		local m = var.modifiers[i]
		if m.kind == KINDS.MODIFIER then -- generic modifier
			if m.value == "const" then
				_M.const(t)
				goto continue
			end

			if m.value == "volatile" then
				_M.volatile(t)
				goto continue
			end
		elseif m.kind == KINDS.POINTER_MODIFIER then
			t = _M.pointer(t)
		elseif m.kind == KINDS.ARRAY_MODIFIER then
			t = _M.array(t)
			t.size = m.size
		end
		::continue::
	end

	return t
end

function _M.isVoid(t)
    return t.kind == TKINDS.BASE and t.type == "void"
end

function _M.isNumericType(t)
    return t.kind == TKINDS.BASE and (
        t.type == "int" or
        t.type == "float" or
        t.type == "double" or
        t.type == "char"
    )
end

function _M.getBaseRoot(t)
    if t.kind == TKINDS.BASE then
        return t
    end

    if t.kind == TKINDS.POINTER then
        return _M.getBaseRoot(t.to)
    end

    if t.kind == TKINDS.ARRAY then
        return _M.getBaseRoot(t.of)
    end
end

function _M.isPointer(t)
	return t.kind == TKINDS.POINTER
end

function _M.isArray(t)
	return t.kind == TKINDS.ARRAY
end

function _M.isStruct(t)
	return t.kind == TKINDS.STRUCT
end

function _M.isFunction(t)
	return t.kind == TKINDS.FUNCTION
end

function _M.isBase(t)
	return t.kind == TKINDS.BASE
end

function _M.equals(a,b)
    if a.kind ~= b.kind then
		return false
	end

	if _M.isBase(a) then
		return a.const == b.const and a.type == b.type and a.numeric == b.numeric and a.sign == b.sign
	end

	if _M.isPointer(a) then
		return a.const == b.const and _M.equals(b.to, a.to)
	end

	if _M.isArray(a) then
		return a.const == b.const and _M.equals(b.of, a.of)
	end
end

function _M.lowEquals(a,b)
    if a.kind ~= b.kind then
		return false
	end

	if _M.isBase(a) then
		return a.type == b.type and a.numeric == b.numeric and a.sign == b.sign
	end

	if _M.isPointer(a) then
		return a.const == b.const and _M.lowEquals(a.to, b.to)
	end

	if _M.isArray(a) then
		return a.const == b.const and _M.lowEquals(b.of, a.of)
	end
end

function _M.canAssign(to, from)
	if not _M.equals(to, from) then
		return false
	end

	return true
end

function _M.canCast(to, from)

    if _M.isNumericType(to) and _M.isNumericType(from) then
        return true
    end

    if _M.isPointer(to) and _M.isPointer(from) then

        if _M.lowEquals(to, from) then
            return true
        end

        if _M.isBase(to.to) and to.to.type == "void" then
            return true
        end

        if _M.isBase(from.to) and from.to.type == "void" then
            return true
        end

        return false
    end

    if _M.isArray(to) or _M.isArray(from) then
        return false
    end

    return false
end

function _M.binary(op, a, b) -- can, result (very restrict, needs cast for everything)
	if _M.isPointer(a) and _M.isNumericType(b) and op == "+" then
    	return true, a
	end
	if not _M.lowEquals(a, b) then
		return false, nil
	end

	return true, a
end

function _M.isPrimitive(t)
	local type = t.type
	if t.to or t.of then
		return _M.isPrimitive(t.to or t.of)
	end
	return type == "int" or type == "float" or type == "char" or type == "double" or type== "void"
end

function _M.sizeof(t)
	if t.kind == TKINDS.POINTER then
		return POINTER_SIZE
	end

	if t.kind == TKINDS.ARRAY then
		local inside_size = _M.sizeof(t.of)

		return inside_size * t.size
	end

	if _M.isBase(t) then
		return types_sizes[t.type][t.numeric or NUMERIC_DEFAULT]
	end

	if _M.isFunction(t) then
		__SEMANTIC.ARGUMENTS:ERROR("Can't get sizeof function")
	end
	
	__SEMANTIC.ARGUMENTS:ERROR(string.format("Can't get sizeof [%s]",tostring(t.type)))
end

return _M