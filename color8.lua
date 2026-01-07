local module = {}

function module.fcolor(r, g, b)
	io.stdout:write(string.format("\027[38;2;%d;%d;%dm", r, g, b))
	return ""
end

function module.bcolor(r, g, b)
	io.stdout:write(string.format("\027[48;2;%d;%d;%dm", r, g, b))
	return ""
end

function module.sfcolor(r, g, b)
	return string.format("\027[38;2;%d;%d;%dm", r, g, b)
end

function module.sbcolor(r, g, b)
	return string.format("\027[48;2;%d;%d;%dm", r, g, b)
end

return module