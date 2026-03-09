local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")

local AST_SPEC, KINDS

do
    local info = require("ASTkinds")
    AST_SPEC, KINDS = info[1], info[2]
end

local _SEMANTIC = _SEMANTIC
local _M = {}

local NUMERIC_SHORT = 0
local NUMERIC_DEFAULT = 1
local NUMERIC_LONG = 2
local NUMERIC_LONGLONG = 3

local POINTER_SIZE = 8

local types_to_kinds = {
    ["int"] = {KINDS.LITERAL_INT},
    ["float"] = {KINDS.LITERAL_FLOAT},
    ["double"] = {KINDS.LITERAL_FLOAT},
    ["char"] = {KINDS.LITERAL_CHAR, KINDS.LITERAL_INT}
}

local types_sizes = {
    ["char"] = {
        [NUMERIC_DEFAULT] = 1
    },
    ["int"] = {
        [NUMERIC_SHORT] = 2,
        [NUMERIC_DEFAULT] = 4,
        [NUMERIC_LONG] = 8,
        [NUMERIC_LONGLONG] = 8
    },
    ["float"] = {
        [NUMERIC_DEFAULT] = 4
    },
    ["double"] = {
        [NUMERIC_DEFAULT] = 8,
        [NUMERIC_LONG] = 8
    },
    ["void"] = {
        [NUMERIC_DEFAULT] = 8
    }
}

local TKINDS = {
    BASE = "_T_BASE",
    POINTER = "_T_POINTER",
    ARRAY = "_T_ARRAY",
    STRUCT = "_T_STRUCT",
    FUNCTION = "_T_FUNCTION",
    LITERAL = "_T_LITERAL"
}

function _M.isNumeric(var)
    return (var.type == "int" or var.type == "float" or var.type == "double" or var.type == "char")
end

function _M.getNumeric(var)
    if not _M.isNumeric(var) then
        return NUMERIC_DEFAULT
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

function _M.base(var, numeric, sign, outside, static, exused)
    return {
        kind = TKINDS.BASE,
        type = var.type,
        numeric = numeric,
        volatile = false,
        sign = sign,
        const = false,
        name = var.name,
        temp = false,
        outside = outside,
        static = static,
        exused = exused
    }
end

function _M.pointer(inner)
    return {
        kind = TKINDS.POINTER,
        const = false,
        volatile = false,
        to = inner,
        temp = false
    }
end

function _M.array(inner)
    return {
        kind = TKINDS.ARRAY,
        const = false,
        volatile = false,
        size = 0,
        of = inner,
        temp = true,
        runtime_size = false
    }
end

function _M.struct(var)
    return {
        kind = TKINDS.STRUCT,
        fields = {},
        temp = false,
        type = var.type
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
        temp = true,
        static = var.static,
        outside = var.outside,
        args = {} -- internal use only
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

function _M.literalInt()
    return {
        kind = TKINDS.LITERAL,
        type = "int",
        numeric = 2,
        volatile = false,
        sign = "signed",
        const = true,
        temp = true
    }
end

function _M.literalFloat()
    return {
        kind = TKINDS.LITERAL,
        type = "float",
        numeric = 3,
        volatile = false,
        sign = "signed",
        const = true,
        temp = true
    }
end

function _M.toBase(lit)
    if lit.kind ~= TKINDS.LITERAL and lit.kind ~= TKINDS.FUNCTION then
        if lit.kind == TKINDS.ARRAY then
            return _M.array(_M.toBase(lit.of))
        end
        if lit.kind == TKINDS.POINTER then
            return _M.pointer(_M.toBase(lit.to))
        end
        return lit
    end
    return {
        kind = TKINDS.BASE,
        type = lit.type,
        numeric = lit.numeric,
        volatile = false,
        sign = lit.sign,
        const = true,
        temp = lit.temp,
        outside = lit.outside,
        fromInit = lit.fromInit,
        static = lit.static
    }
end

function _M.literalToBase(lit)
    return _M.toBase(lit)
end

function _M.functionToBase(fuc)
    return _M.toBase(fuc)
end

function _M.copyBase(t)
    return {
        kind = TKINDS.BASE,
        type = t.type,
        numeric = t.numeric,
        volatile = false,
        sign = t.sign,
        const = false,
        temp = false,
        outside = t.outside,
        fromInit = t.fromInit,
        static = t.static
    }
end

function _M.dereference(p)
    return p.to
end

function _M.decay(a)
    if not _M.isArray(a) and not _M.isPointer(a) then
        return a
    end
    if _M.isPointer(a) then
        a.to = _M.decay(a)
        return a
    end
    if _M.isArray(a.of) then
        a.of = _M.decay(a.of)
    end
    a.to = a.of
    a.of = nil
    a.runtime_size = nil
    a.compile_time_size = nil
    a.kind = TKINDS.POINTER
    return a
end

local function see_bounds_of_array(t, var)
    local now = t
    while true do
        if _M.isArray(now) and not _M.isBase(now.of) then
            if not now.compile_time_size then
                _SEMANTIC.ARGUMENTS:ERROR("multidimensional array must have bounds for all dimensions except the first")
            end
        end

        if not now.of or not _M.isArray(now.of) then
            break
        end

        now = now.of
    end

    if var.kind == KINDS.VAR_DECLARATION_PROTOTYPE then
        if _M.isArray(t) and not now.compile_time_size then
            _SEMANTIC.ARGUMENTS:ERROR("assumed to have one element")
        end
    end
end

function _M.fillStruct(var, t)
    for i, node in ipairs(var.variables) do
        local name = node.name
        local _lt = _M.build(node)
        _lt.name = name
        t.fields[name] = _lt
    end
    return t
end

function _M.build(var)
    if var.kind == KINDS.LITERAL_INT then
        return _M.literalInt()
    end

    if var.kind == KINDS.LITERAL_FLOAT then
        return _M.literalFloat()
    end

    local modifiers = var.modifiers
    local qualifiers = var.qualifiers

    local t

    if var.kind == KINDS.STRUCT_DECLARATION or var.kind == KINDS.STRUCT_DECLARATION_PROTOTYPE then
        t = _M.struct(var)
        if var.kind == KINDS.STRUCT_DECLARATION_PROTOTYP then
            t.prototype = true
        else
            t = _M.fillStruct(var, t)
        end
        return t
    end

    if var.kind == KINDS.FUNCTION_DECLARATION then
        t = _M._function(var)
        t.prototype = false
    elseif var.kind == KINDS.FUNCTION_DECLARATION_PROTOTYPE then
        t = _M._function(var)
        t.prototype = true
    else
        if qualifiers.struct then
            t = _M.struct(var)
        else
            t = _M.base(var, _M.getNumeric(var), qualifiers.sign, qualifiers.outside, qualifiers.static,
                qualifiers.exused)
        end
    end

    for i, m in ipairs(var.modifiers) do
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
            local _t = _M.array(t)
            _t.size = m.size
            _t.runtime_size = m.runtime_size
            _t.compile_time_size = m.compile_time_size
            t = _t
        end
        ::continue::
    end

    see_bounds_of_array(t, var)

    return t
end

function _M.isVoid(t)
    return t.kind == TKINDS.BASE and t.type == "void"
end

function _M.isNumericType(t)
    return t.kind == TKINDS.BASE and (t.type == "int" or t.type == "float" or t.type == "double" or t.type == "char")
end

function _M.isLiteralNumeric(t)
    return t.kind == TKINDS.LITERAL and (t.type == "int" or t.type == "float" or t.type == "double" or t.type == "char")
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

    if t.kind == TKINDS.FUNCTION then
        return t
    end

    return t
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

function _M.isLiteral(t)
    return t.kind == TKINDS.LITERAL
end

function _M.isTemp(t)
    return t.temp == true
end

function _M.resolveLiteral(value, target)

    if _M.isLiteral(value) then
        local base = _M.copyBase(_M.getBaseRoot(target))
        base.const = true
        base.temp = true
        return base
    end

    if _M.isArray(value) and _M.isArray(target) then
        local t = _M.array(_M.resolveLiteral(value.of, target.of))
        t.size = value.size
        return t
    end

    if _M.isPointer(value) and _M.isPointer(target) then
        return _M.pointer(_M.resolveLiteral(value.to, target.to))
    end

    return value
end

function _M.integerPromotion(t)
    if not _M.isNumericType(t) then
        return nil
    end

    local result = _M.copyBase(t)

    -- char -> int

    if t.type == "char" then
        result.type = "int"
        result.numeric = NUMERIC_DEFAULT
    end

    -- short -> int
    if t.type == "int" and t.numeric == NUMERIC_SHORT then
        result.type = "int"
        result.numeric = NUMERIC_DEFAULT
    end

    local baseT = _M.getBaseRoot(t)
    local baseR = _M.getBaseRoot(result)

    if not _M.lowEquals(baseT, baseR) then
        _SEMANTIC.ARGUMENTS:WARN(string.format("(integer promotion) %s -> %s", baseT.type, baseR.type))
    end

    return result
end

function _M.arithmeticPromotion(a, b)

    if _M.isLiteral(a) and not _M.isLiteral(b) then
        a = _M.resolveLiteral(a, b)
    elseif _M.isLiteral(b) and not _M.isLiteral(a) then
        b = _M.resolveLiteral(b, a)
    end

    local originalA = _M.copyBase(a)
    local originalB = _M.copyBase(b)

    a = _M.integerPromotion(a)
    b = _M.integerPromotion(b)

    local result

    if a.type == "double" or b.type == "double" then
        result = {
            kind = TKINDS.BASE,
            type = "double",
            numeric = NUMERIC_DEFAULT,
            volatile = false,
            sign = "signed",
            const = false
        }

    elseif a.type == "float" or b.type == "float" then
        result = {
            kind = TKINDS.BASE,
            type = "float",
            numeric = NUMERIC_DEFAULT,
            volatile = false,
            sign = "signed",
            const = false
        }

    else
        local na = a.numeric or NUMERIC_DEFAULT
        local nb = b.numeric or NUMERIC_DEFAULT

        if na >= nb then
            result = _M.copyBase(a)
        else
            result = _M.copyBase(b)
        end
    end

    local baseA = _M.getBaseRoot(originalA)
    local baseB = _M.getBaseRoot(originalB)
    local baseT = _M.getBaseRoot(result)

    if not _M.equals(originalA, baseT) then
        _SEMANTIC.ARGUMENTS:WARN(string.format("(arithmetic promotion) %s -> %s", baseA.type, baseT.type))
    end

    if not _M.equals(originalB, baseT) then
        _SEMANTIC.ARGUMENTS:WARN(string.format("(arithmetic promotion) %s -> %s", baseB.type, baseT.type))
    end

    return result
end

function _M.equals(a, b)
    if _M.isLiteral(a) then
        a = _M.toBase(a)
    end

    if _M.isLiteral(b) then
        b = _M.toBase(b)
    end

    if _M.isArray(a) then

        a = _M.decay(a)
    end

    if _M.isArray(b) then

        b = _M.decay(b)
    end

    if a.kind ~= b.kind then
        return false, "Incompatible Kinds"
    end

    if _M.isBase(a) then
        if a.numeric ~= b.numeric then
            local baseA = _M.getBaseRoot(a)
            local baseB = _M.getBaseRoot(b)

            _SEMANTIC.ARGUMENTS:WARN(string.format("Converting [%d] : [%d]", baseA.numeric, baseB.numeric))
        end

        return a.type == b.type and a.sign == b.sign, "Base"
    end

    if _M.isPointer(a) then
        return a.const == b.const and _M.equals(b.to, a.to), "Pointer"
    end

    if _M.isArray(a) then
        if not a.size then
            a.size = b.size
        end
        if not b.size then
            b.size = a.size
        end

        local low, err = _M.lowNumEquals(b.of, a.of)
        if not low then
            return false, err
        end
        local equal = a.const == b.const
        if a.runtime_size or b.runtime_size then
            if type(a.size) ~= "table" and type(b.size) ~= "table" and a.size and b.size then
                _SEMANTIC.ARGUMENTS:ERROR("arrays have diferent sizes")
            end
            _SEEMANTIC.ARGUMENTS:ERROR("variable-sized object may not be initialized")
        else
            if type(a.size) ~= "table" and type(b.size) ~= "table" and a.size and b.size then
                if a.size ~= b.size then
                    _SEMANTIC.ARGUMENTS:ERROR(string.format("arrays \"%s\" \"%s\" have diferent sizes",
                        _M.getBaseRoot(a).name or "__constructor", _M.getBaseRoot(b).name or "__constructor"))
                end
            else
                _SEMANTIC.ARGUMENTS:ERROR(string.format("arrays  \"%s\" \"%s\" have diferent sizes",
                    _M.getBaseRoot(a).name or "__constructor", _M.getBaseRoot(b).name or "__constructor"))
            end
        end

        return equal and low, "array"
    end

    if _M.isFunction(a) then
        if #a.args ~= #b.args then
            return false
        end

        for i, argA in ipairs(a.args) do
            local dargA = argA
            if _M.isArray(argA) then
                dargA = _M.decay(argA)
            end
            local dargB = b.args[i]
            if _M.isArray(dargB) then
                dargB = _M.decay(dargB)
            end

            local r = _M.lowEquals(dargA, dargB)
            if not r then
                return false, "Incompatible arguments"
            end
        end
        return a.const == b.const and a.type == b.type and a.numeric == b.numeric and a.sign == b.sign and a.name ==
                   b.name, "Function"
    end

    if _M.isLiteral(a) then
        if a.type == b.type then
            return true
        end
    end

    return nil, "None"
end

function _M.lowEquals(a, b)

    if #a > 0 and #b > 0 then
        if #a ~= #b then
            return false, "Incompatible tableLOW"
        end
    end

    if #a > 0 then
        for _, v in ipairs(a) do
            if not _M.lowEquals(v, b) then
                return false, "Low equal?LOW"
            end
        end
        return true
    end

    if #b > 0 then
        for _, v in ipairs(b) do
            if not _M.lowEquals(v, a) then
                return false, "Low equal?LOW"
            end
        end
        return true
    end

    if _M.isLiteral(a) then
        a = _M.toBase(a)
    end

    if _M.isLiteral(b) then
        b = _M.toBase(b)
    end

    if _M.isArray(a) then

        a = _M.decay(a)
    end

    if _M.isArray(b) then

        b = _M.decay(b)
    end

    if a.kind ~= b.kind then
        return false, string.format("Incompatible Kinds \"%s\" != \"%s\"", a.kind, b.kind)
    end

    if _M.isBase(a) then
        return a.type == b.type and a.numeric == b.numeric, "baseLOW"
    end

    if _M.isPointer(a) then
        return a.const == b.const and _M.lowEquals(a.to, b.to), "pointerLOW"
    end

    if _M.isArray(a) then
        if not a.size then
            a.size = b.size
        end
        if not b.size then
            b.size = a.size
        end

        local low, err = _M.lowNumEquals(b.of, a.of)
        if not low then
            return false, err
        end
        local equal = a.const == b.const
        if a.runtime_size or b.runtime_size then
            if type(a.size) ~= "table" and type(b.size) ~= "table" and a.size and b.size then
                _SEMANTIC.ARGUMENTS:ERROR("arrays have diferent sizes")
            end
            _SEEMANTIC.ARGUMENTS:ERROR("variable-sized object may not be initialized")
        else
            if type(a.size) ~= "table" and type(b.size) ~= "table" and a.size and b.size then
                if a.size ~= b.size then
                    _SEMANTIC.ARGUMENTS:ERROR(string.format("arrays \"%s\" \"%s\" have diferent sizes",
                        _M.getBaseRoot(a).name or "__constructor", _M.getBaseRoot(b).name or "__constructor"))
                end
            else
                if type(a.size) ~= "table" and type(b.size) ~= "table" and a.size and b.size then
                    if a.size ~= b.size and not (a.compile_time_size or b.compile_time_size) then
                        local err = false
                        if a.compile_time_size then
                            if b.size > a.size then
                                err = true
                            end
                        elseif b.compile_time_size then
                            if a.size > b.size then
                                err = true
                            end
                        end
                        if err then
                            _SEMANTIC.ARGUMENTS:ERROR(string.format("arrays NUM \"%s\" \"%s\" have diferent sizes",
                                _M.getBaseRoot(a).name or "__constructor", _M.getBaseRoot(b).name or "__constructor"))
                        end
                    end
                end
            end
        end

        return equal and low, "arrayLOW"
    end

    if _M.isFunction(a) then
        if #a.args ~= #b.args then
            return false, "Function arguments givenLOW"
        end

        for i, argA in ipairs(a.args) do
            local dargA = argA
            if _M.isArray(argA) then
                dargA = _M.decay(argA)
            end
            local dargB = b.args[i]
            if _M.isArray(dargB) then
                dargB = _M.decay(dargB)
            end

            local r = _M.lowEquals(dargA, dargB)
            if not r then
                return false
            end
        end
        return a.type == b.type and a.numeric == b.numeric and a.sign == b.sign and a.name == b.name
    end

    if _M.isLiteral(a) then
        if a.type == b.type then
            return true
        end
    end

    return nil, "NoneLOW"
end

function _M.lowNumEquals(a, b)

    if #a > 0 and #b > 0 then
        if #a ~= #b then
            return false, "Incompatible tableNUM"
        end
    end

    if #a > 0 then
        for _, v in ipairs(a) do
            if not _M.lowNumEquals(v, b) then
                return false, "Low equal?NUM"
            end
        end
        return true
    end

    if #b > 0 then
        for _, v in ipairs(b) do
            if not _M.lowNumEquals(v, a) then
                return false, "Low equal?NUM"
            end
        end
        return true
    end

    if _M.isLiteral(a) then
        a = _M.toBase(a)
    end

    if _M.isLiteral(b) then
        b = _M.toBase(b)
    end

    if _M.isArray(a) then

        a = _M.decay(a)
    end

    if _M.isArray(b) then

        b = _M.decay(b)
    end

    if a.kind ~= b.kind then

        return false, string.format("Incompatible Kinds \"%s\" != \"%s\"", a.kind, b.kind)
    end

    if _M.isBase(a) then

        local l, e = a.type == b.type, "baseNUM" .. a.type .. b.type
        return l, e
    end

    if _M.isPointer(a) then
        local baseA = _M.getBaseRoot(a)
        local baseB = _M.getBaseRoot(b)
        if baseA.type == "void" or baseB.type == "void" then
            return "pointerNUM void"
        end
        local can, err = _M.lowNumEquals(a.to, b.to)
        return can, err
    end

    if _M.isArray(a) then
        if not a.size then
            a.size = b.size
        end
        if not b.size then
            b.size = a.size
        end

        local low, err = _M.lowNumEquals(b.of, a.of)
        if not low then
            return false, err
        end

        local equal = a.const == b.const
        if a.runtime_size or b.runtime_size then
            if type(a.size) ~= "table" and type(b.size) ~= "table" and a.size and b.size then
                _SEMANTIC.ARGUMENTS:ERROR("arrays have diferent sizes")
            end
            _SEEMANTIC.ARGUMENTS:ERROR("variable-sized object may not be initialized")
        else
            if type(a.size) ~= "table" and type(b.size) ~= "table" and a.size and b.size then
                if a.size ~= b.size then
                    local err = false
                    local size_err = false

                    if not (a.compile_time_size or b.compile_time_size) then
                        err = true
                    end

                    local err = false
                    if a.compile_time_size then
                        if b.size > a.size then
                            size_err = true
                        end
                    elseif b.compile_time_size then
                        if a.size > b.size then
                            size_err = true
                        end
                    end

                    if err then
                        _SEMANTIC.ARGUMENTS:ERROR(string.format("arrays NUM \"%s\" \"%s\" have diferent sizes",
                            _M.getBaseRoot(a).name or "__constructor", _M.getBaseRoot(b).name or "__constructor"))
                    end
                    if size_err then
                        _SEMANTIC.ARGUMENTS:ERROR(string.format(
                            "arrays NUM \"%s\" \"%s\" excess elements in array initializer",
                            _M.getBaseRoot(a).name or "__constructor", _M.getBaseRoot(b).name or "__constructor"))
                    end
                end
            end
        end

        return equal and low, "arrayNUM"
    end

    if _M.isFunction(a) then
        if #a.args ~= #b.args then
            return false
        end

        for i, argA in ipairs(a.args) do
            local dargA = argA
            if _M.isArray(argA) then
                dargA = _M.decay(argA)
            end
            local dargB = b.args[i]
            if _M.isArray(dargB) then
                dargB = _M.decay(dargB)
            end
            local r = _M.lowNumEquals(dargA, dargB)
            if not r then
                return false
            end
        end
        return a.type == b.type and a.sign == b.sign and a.name == b.name
    end

    if _M.isLiteral(a) then
        if a.type == b.type then
            return true
        end
    end

    if _M.isStruct(a) then
        return a.type == b.type, string.format("Struct type \"%s\" \"%s\"", a.type, b.type)
    end

    return false, "NoneNUM == " .. a.kind
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
        return false, "array"
    end

    return false, "None"
end

function _M.binary(op, a, b)
    if _M.isPointer(a) and (_M.isNumericType(b) or _M.isLiteralNumeric(b)) and (op == "+" or op == "-") and b.type ==
        "int" then
        return true, a
    end

    if _M.isPointer(b) and (_M.isNumericType(a) or _M.isLiteralNumeric(a)) and (op == "+" or op == "-") and a.type ==
        "int" then
        return true, b
    end

    if _M.isArray(a) or _M.isArray(b) then
        return false, nil
    end

    a.temp = true
    b.temp = true

    if _M.isLiteral(a) then
        a = _M.literalToBase(a)
    end

    if _M.isLiteral(b) then
        b = _M.literalToBase(b)
    end

    if _M.isNumericType(a) and _M.isNumericType(b) then
        local result = _M.arithmeticPromotion(a, b)
        result.temp = true
        if not result then
            return false, nil
        end

        if op == "//" then
            result.type = "int"
            return true, result
        end

        return true, result
    end

    return false, nil
end

function _M.unary(op, a) -- can, result (very restrict, needs cast for everything)
    if _M.isPointer(a) then
        return false
    end

    if _M.isArray(a) then
        return false
    end

    if _M.isFunction(a) then
        return false
    end

    return true
end

function _M.isPrimitive(t)
    local type = t.type
    if t.to or t.of then
        return _M.isPrimitive(t.to or t.of)
    end
    return type == "int" or type == "float" or type == "char" or type == "double" or type == "void"
end

function _M.sizeof(t)
    if t.kind == TKINDS.POINTER then
        return POINTER_SIZE
    end

    if t.kind == TKINDS.ARRAY then
        if t.runtime_size then
            return POINTER_SIZE
        end
        local inside_size = _M.sizeof(t.of)

        return inside_size * t.size
    end

    if _M.isBase(t) then
        return types_sizes[t.type][t.numeric or NUMERIC_DEFAULT]
    end

    if _M.isFunction(t) then
        _SEMANTIC.ARGUMENTS:ERROR("Can't get sizeof function")
    end

    _SEMANTIC.ARGUMENTS:ERROR(string.format("Can't get sizeof [%s]", tostring(t.type)))
end

return _M
