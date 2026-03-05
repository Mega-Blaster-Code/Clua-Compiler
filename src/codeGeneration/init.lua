local inspect = require("C_inspect")
local file2io = require("file2io")
local color8 = require("color8")
local lfs = require("lfs")

local AST_SPEC, KINDS

do
    local info = require("ASTkinds")
    AST_SPEC, KINDS = info[1], info[2]
end

local targets_path = "./src/codeGeneration/targets"

local _M = {}

local targets = {}

local generation = {}
generation.__index = generation

function _M.load(ARGUMENTS)
	if type(ARGUMENTS:GET_FLAG("-tarpath")) == "string" then
        targets_path = ARGUMENTS:GET_FLAG("-tarpath")
    end

    for name in lfs.dir(targets_path) do
        if name == "." or name == ".." then
            goto continue
        end

        if name:sub(-4, -1) ~= ".lua" then
            goto continue
        end

		local mod_name = name:sub(1, -5)

		local module =  require(targets_path .. "/" .. mod_name)

		if type(module) ~= "table" then
			ARGUMENTS:WARN(string.format("Target [%s%s%s] is not a valid target module (%s)", color8.sfcolor(255, 100, 255), mod_name, color8.sreset(), type(module)))
			goto continue
		end

		if type(module.lower) ~= "function" then
			ARGUMENTS:WARN(string.format("Target [%s%s%s] don't have a lower function (%s)", color8.sfcolor(255, 100, 255), mod_name, color8.sreset(), type(module.lower)))
			goto continue
		end

		if type(module.emit) ~= "function" then
			ARGUMENTS:WARN(string.format("Target [%s%s%s] don't have a emit function (%s)", color8.sfcolor(255, 100, 255), mod_name, color8.sreset(), type(module.emit)))
			goto continue
		end

        targets[mod_name] = module

        ::continue::
    end
end

function _M.new(dest_file_path, target, AST_TREE, ARGUMENTS)
    local self = setmetatable({}, generation)

    self.file_path = dest_file_path
    self.AST = AST_TREE
    self.ARGUMENTS = ARGUMENTS
	self.target = target

	self.tar_module = targets[target]

	if not self.tar_module then
		ARGUMENTS:ERROR(string.format("Target [%s%s%s] don't exist in \"%s\"", color8.sfcolor(255, 100, 255), target, color8.sreset(), targets_path))
	end

    return self
end

function generation:start()
	local lowered_ast = self.tar_module.lower(self.AST)

	local out_content = self.tar_module.emit(lowered_ast)

	return out_content
end

return _M
