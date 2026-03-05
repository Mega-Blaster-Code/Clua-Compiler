local _M = {}

function _M.lower(ast)
	return ast
end

function _M.emit(ast)
	return "int x = 10;"
end

return _M