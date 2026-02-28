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

--[[

char            = 8 
int             = 32
float           = 32
int short       = 16
int long        = 64
int long long   = 64
double          = 64
double long     = 64

]]

local TKINDS = {
	BASE = "_T_BASE",
	POINTER = "_T_POINTER",
	ARRAY = "_T_ARRAY",
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

function _M.base(type, numeric, sign)
	return {
		kind = TKINDS.BASE,
		type = type,
		numeric = numeric,
		volatile = false,
		sign = sign,
		const = false,
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
		kind = TKINDS.POINTER,
		const = false,
		volatile = false,
		of = inner,
	}
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

	local t = _M.base(var.type, _M.getNumeric(var), qualifiers.sign)

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
		end
		::continue::
	end

	return t
end

function _M.isPointer(t)
	return t.kind == TKINDS.POINTER
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
end

function _M.canAssign(to, from) -- (very restrict, needs cast for everything)
	if not _M.equals(to, from) then
		return false
	end

	return true
end

function _M.binary(op, a, b) -- can, result (very restrict, needs cast for everything)
	if not _M.lowEquals(a, b) then
		return false, nil
	end

	return true, a
end

function _M.sizeof(t)
	
end

return _M