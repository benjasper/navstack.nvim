Utils = require "navstack.utils"

---@class FileEntry
---@field name string
---@field path string
---@field full_path string
---@field is_current boolean
---@field is_pinned boolean
---@field is_temporary boolean
---@field is_modified boolean
---@field is_duplicate_name boolean
---@field diagnostics table<vim.diagnostic.Severity, integer>
---@field icon string
---@field icon_hl string
local FileEntry = {}

---@param name string
---@param path string
---@param is_current boolean
---@param is_temporary boolean
---@param full_path string
function FileEntry:new(name, path, is_current, is_temporary, full_path)
	local obj = {
		name = name,
		path = path,
		is_current = is_current,
		is_temporary = is_temporary,
		is_pinned = false,
		full_path = full_path,
		is_modified = false,
		is_duplicate_name = false,
		diagnostics = {},
		icon = "",
		icon_hl = "",
	}

	setmetatable(obj, self)
	self.__index = self

	obj.icon, obj.icon_hl = Utils.get_icon(obj.name)

	return obj
end

---@class SerializedFile
---@field full_path string
---@field is_temporary boolean
---@field is_current boolean
---@field is_pinned boolean

---@return SerializedFile
function FileEntry:serialize()
	return {
		is_temporary = self.is_temporary,
		full_path = self.full_path,
		is_pinned = self.is_pinned,
	}
end

---@param diagnostics table<vim.diagnostic.Severity, integer>
function FileEntry:set_diagnostics(diagnostics)
	self.diagnostics = diagnostics
end

function FileEntry:render_title()
	local padding = "  "

	local icon = ""

	if self.is_pinned then
		icon = icon .. "󰐃 "
	end

	if self.is_modified then
		icon = icon .. "● "
	end

	return padding .. icon .. self.icon .. " " .. self.name
end

return FileEntry
