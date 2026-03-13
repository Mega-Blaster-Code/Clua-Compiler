local _M = {}

local lexer = require("AFS/lexer")

local color8 = require("color8")
local inspect = require("C_inspect")

local TYPES = {
    POINTER = "__POINTER",
    BUFFER = "__BUFFER",
    BUILTIN = "__BUILTIN",
	NULL = "__NULL",
}

local buffer = {}
buffer.__index = buffer

local function new_buffer()
	local self = setmetatable({}, buffer)

	self.data = {}

	return self
end

function buffer:write(data)
	self.data[#self.data + 1] = data
end

function buffer:read()
	return table.concat(self.data)
end

local function create_builtin()
    local function default_function()

    end

    local built_in = {
        f = {
            can_call = true,
            call_func = function(self, self_f, file_name)
				local buffer = self:new_buffer(file_name)
				local err
				buffer.buffer, err = io.open(file_name, "rb")
				if buffer.buffer == nil then
					self:ERROR("F " .. err)
				end
            end,

            can_point = false,

			can_system_call = false,

			pointer = nil,

            type = TYPES.BUILTIN,

			can_has_default_buffer = false,

			default_buffer = nil,
			name = "f",
        },
		wf = {
            can_call = true,
            call_func = function(self, self_f, file_name)
				local buffer = self:new_buffer(file_name)
				local err
				buffer.buffer, err = io.open(file_name, "w+b")
				if buffer.buffer == nil then
					self:ERROR("WF " .. err)
				end
            end,

            can_point = false,

			can_system_call = false,

			pointer = nil,

            type = TYPES.BUILTIN,

			can_has_default_buffer = false,

			default_buffer = nil,
			name = "wf",
        },
		["w+f"] = {
            can_call = true,
            call_func = function(self, self_f, file_name)
				local buffer = self:new_buffer(file_name)
				local err
				buffer.buffer, err = io.open(file_name, "w+b")
				if buffer.buffer == nil then
					self:ERROR("W+F '" .. err .. "' => " .. tostring(file_name))
				end
            end,

            can_point = false,

			can_system_call = false,

			pointer = nil,

            type = TYPES.BUILTIN,

			can_has_default_buffer = false,

			default_buffer = nil,
			name = "w+f",
        },
		W = {
			can_call = false,
			can_point = false,

			can_system_call = true,

			system = function(self, self_W, msg)
				if self.builtin_flags["--Werror"] then
					self:ERROR(msg)
				end
				local buffer = self.buffers[self_W.default_buffer.name]
				if not buffer then
					io.stderr:write(string.format("%sERROR%s: %s\n", color8.sfcolor(255, 0, 0), color8.sfcolor(200, 200, 200), ": AFS can't acess default buffer for WARN"))
					os.exit(self.errorc)
				end
				
				if buffer.name == "STDERR" then
					buffer.buffer:write(string.format("%sWARNING%s: %s\n", color8.sfcolor(255, 127, 0), color8.sfcolor(200, 200, 200), msg))
				else
					msg = color8.strip_rgb(msg) or msg
					buffer.buffer:write(string.format("WARNING: %s\n", msg))
				end
			end,

			pointer = nil,
			type = TYPES.BUILTIN,

			can_has_default_buffer = true,

			default_buffer = {name = "STDERR"},
			name = "W",
		},
		E = {
			can_call = false,
			can_point = false,

			can_system_call = true,

			system = function(self, self_E, msg)
				local buffer = self.buffers[self_E.default_buffer.name]
				if not buffer then
					io.stderr:write(string.format("%sERROR%s: %s\n", color8.sfcolor(255, 0, 0), color8.sfcolor(200, 200, 200), ": AFS can't acess default buffer for WARN"))
					os.exit(self.errorc)
				end

				if buffer.name == "STDERR" then
					buffer.buffer:write(string.format("%sERROR%s: %s\n", color8.sfcolor(255, 0, 0), color8.sfcolor(200, 200, 200), msg))
				else
					msg = color8.strip_rgb(msg) or msg
					buffer.buffer:write(string.format("ERROR: %s\n", msg))
				end


				os.exit(self.errorc)
			end,

			pointer = nil,
			type = TYPES.BUILTIN,

			can_has_default_buffer = true,

			default_buffer = {name = "STDERR"},
			name = "E",
		},
		I = {
			can_call = false,
			can_point = false,

			can_system_call = true,

			system = function(self, self_I, msg)
				
				local buffer = self.buffers[self_I.default_buffer.name]
				if not buffer then
					io.stderr:write(string.format("%sERROR%s: %s\n", color8.sfcolor(255, 0, 0), color8.sfcolor(200, 200, 200), ": AFS can't acess default buffer for WARN"))
					os.exit(self.errorc)
				end
				
				if buffer.name == "STDERR" then
					buffer.buffer:write(string.format("%sINFO%s: %s\n", color8.sfcolor(100, 100, 100), color8.sfcolor(200, 200, 200), msg))
				else
					msg = color8.strip_rgb(msg) or msg
					buffer.buffer:write(string.format("INFO: %s\n", msg))
				end
			end,

			pointer = nil,
			type = TYPES.BUILTIN,

			can_has_default_buffer = true,

			default_buffer = {name = "STDERR"},
			name = "I",
		},
		STDERR = {
			can_call = false,

            can_point = true,

			can_system_call = false,

			pointer = nil,

            type = TYPES.POINTER,

			can_has_default_buffer = false,

			default_buffer = nil,
			const = true,
			name = "STDERR",
		},
		STDOUT = {
			can_call = false,

            can_point = true,

			can_system_call = false,

			pointer = nil,

            type = TYPES.POINTER,

			can_has_default_buffer = false,

			default_buffer = nil,

			const = true,
			name = "STDOUT",
		},
		VOID = {
			can_call = false,

            can_point = true,

			can_system_call = false,

			pointer = nil,

            type = TYPES.POINTER,

			can_has_default_buffer = false,

			default_buffer = nil,

			const = true,
			name = "VOID",
		}
    }
	return built_in
end

local FLAG_TOKENS = {
    SEMICOLON = "__SEMICOLON",
    NAME = "__NAME",

    COMMA = "__COMMA",
    COLON = "__COLON",

    POINTER = "__POINTER",

    CALL = "__CALL",

    LINE_COMMENT = "__LINE_COMMENT",

    NUMBER_INT = "__NUMBER",

    CUSTOM_FLAG = "__CUSTOM_FLAG",
    BUILTIN_FLAG = "__BUILTIN_FLAG",
    PLUS = "__PLUS"
}

local vm = {}
vm.__index = vm

local function VOIDbuffer(self)
	local buffer = self:new_buffer("VOID")
	buffer.buffer = new_buffer()
	return buffer
end

function _M.new(tokens)

    local self = setmetatable({}, vm)

	self.built_in = create_builtin()

    self.tokens = tokens

	self.errorc = 1
	
    self.flags = {}

	self.buffers = {
		STDOUT = {name = "STDOUT", buffer = io.stdout, pointer_count = math.huge, type = TYPES.BUFFER},
		STDERR = {name = "STDERR", buffer = io.stderr, pointer_count = math.huge, type = TYPES.BUFFER},
		VOID = {name = "VOID", buffer = nil, pointer_count = math.huge, type = TYPES.BUFFER},
	}
	
	self.built_in.STDERR.pointer = self.buffers.STDERR
	self.built_in.STDOUT.pointer = self.buffers.STDOUT
	self.built_in.VOID.pointer = self.buffers.VOID

	self.builtin_flags = {}

	self.custom_flags = {}

	self.buffers.VOID.buffer = VOIDbuffer(self)

    self.pos = 1

    return self
end

function vm:INFO(msg)
	self.built_in.I.system(self, self.built_in.I, msg)
end

function vm:WARN(msg)
	if self.builtin_flags["--Wnone"] then
		return
	end
	if self.builtin_flags["--Werror"] then
		self:ERROR(string.format("%s%s%s%s", msg, color8.sfcolor(255, 150, 50), "\n**all warnings being treated as errors**", color8.sfcolor(200, 200, 200)))
		return
	end
	self.built_in.W.system(self, self.built_in.W, msg)
end

function vm:ERROR(msg)
	self.built_in.E.system(self, self.built_in.E, msg)
end

function vm:new_NULL()
	return {
		type = TYPES.NULL,
	}
end

function vm:new_pointer(name)
    self.flags[name] = {
        can_call = false,
        call_func = nil,
        can_point = true,

		pointer = self:new_NULL(),

		name = name,

        type = TYPES.POINTER
    }
	return self.flags[name]
end

function vm:new_buffer(name)
	local pointer = self:new_pointer(name)

	self.buffers[name] = {
		pointer_count = 1,
		type = TYPES.BUFFER,
		buffer = nil,
		name = name
	}

	pointer.pointer = self.buffers[name]

	return self.buffers[name]
end

function vm:is_builtin(name)
    return self.built_in[name]
end

function vm:can_point(name)
    local flag = self:flag_exist(name)
    if not flag then
        return false
    end
    return flag.can_point
end

function vm:can_call(name)
    local flag = self:flag_exist(name)
    if not flag then
        return false
    end
    return flag.can_call
end

function vm:is_buffer(name)
    local flag = self:flag_exist(name)
    if not flag then
        return false
    end
    return flag.types == TYPES.BUFFER
end

function vm:flag_exist(name)
    return self.built_in[name] or self.flags[name]
end

function vm:builtin_flag(name)
    return self.builtin_flags[name]
end

function vm:consume()
    local t = self.tokens[self.pos]
    self.pos = self.pos + 1
    return t
end

function vm:Econsume()
    local t = self.tokens[self.pos]
    if not t then
        self:ERROR("Can't consume")
    end
    self.pos = self.pos + 1
    return t
end

function vm:peek(length)
    length = length or 0
    return self.tokens[self.pos + length]
end

function vm:expect(token, length)
    length = length or 0
    local t = self:peek(length)
    if t and t.token == token then
        return t
    end
    return false
end

function vm:Cexpect(token, length)
    length = length or 0
    local t = self:peek(length)
    if t and t.token == token then
        return self:consume()
    end
    return false
end

function vm:Eexpect(token, length)
    length = length or 0
    local t = self:peek(length)
    if t and t.token == token then
        return t
    end
    self:ERROR(string.format("Expected ['%s'] but received ['%s']", token, tostring((t or {}).token)))
end

function vm:CEexpect(token, length)
    length = length or 0
    local t = self:peek(length)
    if t and t.token == token then
        return self:consume()
    end
    self:ERROR(string.format("Expected ['%s'] but received ['%s']", token, tostring((t or {}).token)))
end

function vm:inside_flag()
    local base = self:CEexpect(FLAG_TOKENS.NAME)
	local base_buf = base.buf
    local type = self:Econsume()

    if type.buf == "@" then -- call
        local flag = self:flag_exist(base_buf)

        if not flag then
            self:ERROR(string.format("trying to call flag '%s' a NULL flag", base_buf))
        end

		if not self:can_call(base_buf) then
			self:ERROR(string.format("flag '%s' is not a function", base_buf))
		end

        local data = self:CEexpect(FLAG_TOKENS.NAME)

        flag.call_func(self, flag ,data.buf)

		return
    end

	if type.buf == "=." then -- point to
        local flag = self:flag_exist(base_buf)

        if not flag then
            flag = self:new_pointer(base_buf)
        end

		if flag.const then
			self:ERROR(string.format("can't modifie const flag '%s'", base_buf))
		end

		if not self:can_point(base_buf) then
			self:ERROR(string.format("flag '%s' can't point", base_buf))
		end

        local data = self:CEexpect(FLAG_TOKENS.NAME)
		local data_buf = data.buf

		local item = self:flag_exist(data_buf)

		if not item then
			if self:builtin_flag("--NO-NULL") then
				self:ERROR(string.format("Pointer can't point to NULL ['%s']", data_buf))
			end

			item = self:new_NULL()
		end

		if flag.pointer.type == TYPES.BUFFER then
			flag.pointer.pointer_count = flag.pointer.pointer_count - 1
		end

		flag.pointer = item

		if flag.pointer.type == TYPES.BUFFER then
			flag.pointer.pointer_count = flag.pointer.pointer_count - 1
		end

		return
    end


	if type.buf == ":" then -- default write
        local flag = self:flag_exist(base_buf)

        if not flag then
            flag = self:new_pointer(base_buf)
        end

		if not flag.can_has_default_buffer then
			self:ERROR(string.format("can't set default buffer of ['%s']", flag.type))
		end

        local data = self:CEexpect(FLAG_TOKENS.NAME)
		local data_buf = data.buf

		local item = self:flag_exist(data_buf)

		if not item then
			self:ERROR(string.format("can't set default buffer to NULL ['%s']", data_buf))
		end

		local buffer =  self:GET_POINTER(data_buf)

		if not flag.default_buffer then
			self:ERROR(string.format("can't set default buffer to a pointer to NULL ['%s']", data_buf))
		end
		
		flag.default_buffer = buffer

		return
    end
end

function vm:start(level)
	level = level or 0
    while self:peek() do
		local c
        if self:expect(FLAG_TOKENS.NAME) then
            self:inside_flag()
            self:CEexpect(FLAG_TOKENS.SEMICOLON)
            goto continue
        end

		if self:expect(FLAG_TOKENS.BUILTIN_FLAG) then
			local flag = self:consume().buf
			local value = true
			if self:expect(FLAG_TOKENS.CALL) then
				self:consume()

				value = self:CEexpect(FLAG_TOKENS.NAME).buf
			end

			self.builtin_flags[flag] = value

			self:CEexpect(FLAG_TOKENS.SEMICOLON)

			if flag == "--LOAD" then
				if level > 200 then
					self:ERROR("Too many calls of --LOAD")
				end
				if type(value) ~= "string" then
					self:ERROR("LOAD need a file name")
				end

				local file = io.open(value, "rb")

				local content = file:read("*all")

				local tokens = lexer.new({content})

				file:close()

				for i, v in ipairs(tokens) do
					table.insert(self.tokens, self.pos + (i - 1), v)
				end
			end

			goto continue
		end

		if self:expect(FLAG_TOKENS.CUSTOM_FLAG) then
			local flag = self:consume().buf
			local value = true
			if self:expect(FLAG_TOKENS.CALL) then
				self:consume()

				value = self:CEexpect(FLAG_TOKENS.NAME).buf
			end

			self.custom_flags[flag] = value

			self:CEexpect(FLAG_TOKENS.SEMICOLON)
			goto continue
		end

		if self:expect(FLAG_TOKENS.SEMICOLON) then
			self:consume()
			goto continue
		end

		c = self:peek() or {}
		
        self:ERROR(string.format("Invalid Statement ['%s'] ['%s']", tostring(c.buf), tostring(c.token)))

        ::continue::

		for k, buffer in pairs(self.buffers) do
			if buffer.pointer_count <= 0 then
				self.buffers[k] = nil
			end
		end
    end

	return self
end

function vm:GET_POINTER(name)
	local flag = self.flags[name] or self.built_in[name]

	if not flag then
		return
	end

	local cache = {}

	while flag.type == TYPES.POINTER do
		if cache[flag.name] then
			self:ERROR("Can't have a loop of pointers")
		end

		cache[flag.name] = true
		flag = flag.pointer
	end

	return flag
end

function vm:GET_FLAG(name)
	local flag = self.custom_flags[name]
	if not flag then
		return nil
	end

	return flag
end

return _M
