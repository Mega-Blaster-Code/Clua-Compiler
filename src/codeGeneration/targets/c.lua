local _M = {}

function _M.lower(ast)
	return ast
end

local AST_SPEC, KINDS

do
    local info = require("ASTkinds")
    AST_SPEC, KINDS = info[1], info[2]
end

local function push(buffer, str)
	buffer[#buffer + 1] = str
end

local function buildVarDeclaration(node)
	local line = {}

	local qualifiers = node.qualifiers
	local modifiers = node.modifiers

	print(qualifiers, modifiers)

	push(line, node.type)

	return table.concat(line, " ")
end

local ANALYZER_BUILD = {
    [KINDS.FUNCTION_DECLARATION] = _M.analyzeFunction,
    [KINDS.FUNCTION_DECLARATION_PROTOTYPE] = _M.analyzeFunction,
    [KINDS.VAR_ASSIGNMENT] = _M.analyzeAssignment,
    [KINDS.VAR_DECLARATION] = buildVarDeclaration,
    [KINDS.VAR_DECLARATION_PROTOTYPE] = buildVarDeclaration,
    [KINDS.IF] = _M.analyzeIf,
    [KINDS.WHILE] = _M.analyzeWhile,
    [KINDS.FOR] = _M.analyzeFor,
    [KINDS.BREAK] = _M.analyzeBreak,
    [KINDS.RETURN] = _M.analyzeReturn,
    [KINDS.VOID_RETURN] = _M.analyzeReturn,
    [KINDS.RAW_DO] = _M.analyzeRawDo,
    [KINDS.PROGRAM] = _M.analyzeProgram,
	[KINDS.EXTERN] = _M.analyzeExtern,
}

function _M.analyze(node)
    local analyzer = ANALYZER_BUILD[node.kind]

    if not analyzer then
        error(string.format("Kind %s was unexpected", tostring(node.kind)), node)
    end

    return analyzer(node)
end

local function emitBlock(node)
	local code = {}
    for i, lnode in ipairs(node) do
        code[#code + 1] = _M.analyze(lnode)
    end

	return table.concat(code, "\n")
end

function _M.emit(ast)
	local code = emitBlock(ast.body)
	return code
end

return _M