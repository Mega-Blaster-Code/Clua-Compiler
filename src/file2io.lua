local module = {}

module.modes = {
    read              = "r",
    write             = "w",
    append            = "a",
    read_write_update = "r+",
    read_write_new    = "w+",
    read_write_append = "a+",

    read_binary              = "rb",
    write_binary             = "wb",
    append_binary            = "ab",
    read_write_update_binary = "r+b",
    read_write_new_binary    = "w+b",
    read_write_append_binary = "a+b",
}

module.read_modes = {
    all = "*all",
    line = "*line",
    number = "*number",
}

module.whence = {
    set = "set",
    cursor = "cur",
    finish = "end",
}

function module.fileExist(path)
    local f = io.open(path, module.modes.read)
    local exist = f ~= nil
    if exist then
        f:close()
    end
    return exist
end

local function hasMode(mode, c)
    return (mode or ""):find(c, 1, true)
end

local function canRead(mode)
    if not mode then return false end
    return hasMode(mode, "r") or hasMode(mode, "+")
end

local function canWrite(mode)
    if not mode then return false end
    return hasMode(mode, "w") or hasMode(mode, "a") or hasMode(mode, "+")
end

local file_type = {}
file_type.__index = file_type

function module.open(file_path, mode)
    local self = setmetatable({}, file_type)
    self.mode = mode or module.modes.read
    self.file_path = file_path

    local handler, err = io.open(file_path, mode)

    if not handler then
        return nil, string.format("Can't open file '%s' : '%s'", file_path, err)
    end

    self.file_handler = handler

    return self
end

function file_type:read(read_mode)
    read_mode = read_mode or module.read_modes.all

    local mode = self.mode

    if not canRead(mode) then
        return nil, string.format("Can't read file in the mode '%s'", mode)
    end

    return self.file_handler:read(read_mode)
end

function file_type:seek(whence, offset)
    return self.file_handler:seek(whence, offset)
end

function file_type:write(contents)
    local mode = self.mode
    if not canWrite(mode) then
        return nil, string.format("Can't write into file in the mode '%s'", mode)
    end
    return self.file_handler:write(contents)
end

function file_type:close()
    return self.file_handler:close()
end

return module
