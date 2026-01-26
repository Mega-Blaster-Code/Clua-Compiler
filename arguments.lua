local inspect = require("inspect")
local file2io = require("file2io")
local color8 = require("color8")

local flags = {
    o = {
        data = "%s",
        used = false,
		receive = 1,
    },
    i = {
        data = "clua",
        used = false,
		receive = 1,
    },
    pp = {
        data = "%s",
        used = false,
		receive = 1,
    },
	PP = {
        data = "",
        used = false,
		receive = 0,
    },
	f = {
		data = "%s",
		used = false,
		receive = 1,
	}
}

local _flags = {}
_flags.__index = _flags

local function new(args)
	local self = setmetatable({}, _flags)

	self.args = args
	self.pos = 1

	self.result = {}

	self:start()
	return self.result
end

function _flags:error(msg, code)
    local left_off = 2
    local right_off = 2

    local pre_arguments = {}
    do -- local variables
        local i = 0
        while i < left_off do
            local left = self.args[-i + self.pos]
            if left then
                table.insert(pre_arguments, {
                    index = -i,
                    ar = left
                })
            end
            i = i + 1
        end
        i = 1
        while i < right_off do
            local right = self.args[i + self.pos]
            if right then
                table.insert(pre_arguments, {
                    index = i,
                    ar = right
                })
            end
            i = i + 1
        end

        table.sort(pre_arguments, function(a, b)
            return a.index < b.index
        end)
    end

    io.stderr:write(msg)
    io.stderr:write(string.format("\nError in ARGUMENTS"))
    io.stderr:write("\n\n")

    for i, arg in ipairs(pre_arguments) do
        io.stderr:write(arg.ar .. " ")
    end

    io.stderr:write("\n")

    color8.error = true
    color8.fcolor(0, 128, 128)
    for i, arg in ipairs(pre_arguments) do
		for j = 1, #arg.ar do
			if arg.index == 0 then
				color8.fcolor(255, 0, 0)
				io.stderr:write("^")
			else
				color8.fcolor(0, 128, 128)
				io.stderr:write("-")
			end
		end
		color8.fcolor(0, 128, 128)
		if i ~= #pre_arguments then
			io.stderr:write("-")
		end
    end
    color8.fcolor(200, 200, 200)
    io.stderr:write("\n")
    os.exit(code or 1)
end

function _flags:peek(length)
	length = length or 0
	return self.args[self.pos + length]
end

function _flags:consume()
	local a = self.args[self.pos]
	self.pos = self.pos + 1
	return a
end

function _flags:expect(pattern, length)
	length = length or 0
	return self.args[self.pos + length]:match(pattern)
end

function _flags:Eexpect(pattern, length)
	length = length or 0
	local s = self.args[self.pos + length]
	local p = s:match(pattern)
	if not p then
		self:error(string.format("Was expecting pattern '%s' but received ['%s']", pattern, s))
	end
	return p
end

function _flags:CEexpect(pattern, length)
	length = length or 0
	local s = self.args[self.pos + length]
	local p = s:match(pattern)
	if not p then
		self:error(string.format("Was expecting pattern '%s' but received ['%s']", pattern, s))
	end
	self:consume()
	return p
end

function _flags:Econsume()
	local a = self.args[self.pos]
	if not a then
		
	end
	self.pos = self.pos + 1
	return a
end

function _flags:start()
	while self:peek() do
		local str = self:peek()
		local crop = str:sub(2, -1)
		if str:sub(1, 1) ~= "-" or not flags[crop] then
			self:error(string.format("Error in arguments for compiler: flag [%d]: '%s':'%s' don't exist", self.pos, str, crop), -self.pos * 10 + 100)
		end

		self:consume()

		local flag = flags[crop]

		local r = {}

		for i = 1, flag.receive do
			local data = self:Econsume()
			r[#r + 1] = data
		end

		self.result[crop] = r
	end
end

return new