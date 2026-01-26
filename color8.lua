local module = {}

module.error = false

function module.fcolor(r, g, b)
	io[(module.error and "stderr") or "stdout"]:write(string.format("\027[38;2;%d;%d;%dm", r, g, b))
	return ""
end

function module.bcolor(r, g, b)
	io[(module.error and "stderr") or "stdout"]:write(string.format("\027[48;2;%d;%d;%dm", r, g, b))
	return ""
end

function module.sfcolor(r, g, b)
	return string.format("\027[38;2;%d;%d;%dm", r, g, b)
end

function module.sbcolor(r, g, b)
	return string.format("\027[48;2;%d;%d;%dm", r, g, b)
end

function module.strip_rgb(str)
	str = str:gsub("\27%[38;2;%d+;%d+;%d+m", "")
	str = str:gsub("\27%[48;2;%d+;%d+;%d+m", "")
	return str
end


return module