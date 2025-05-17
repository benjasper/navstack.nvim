---@class FileEntry
---@field name string
---@field path string
---@field full_path string
---@field is_current boolean
---@field is_temporary boolean
---@field is_modified boolean
---@field diagnostics table<vim.diagnostic.Severity, integer>
local FileEntry = {}

---@param name string
---@param path string
---@param is_current boolean
---@param is_temporary boolean
function FileEntry:new(name, path, is_current, is_temporary, full_path)
	local obj = {
		name = name,
		path = path,
		is_current = is_current,
		is_temporary = is_temporary,
		full_path = full_path,
		is_modified = false,
		diagnostics = {},
	}

	setmetatable(obj, self)
	self.__index = self
	return obj
end

---@param diagnostics table<vim.diagnostic.Severity, integer>
function FileEntry:set_diagnostics(diagnostics)
	self.diagnostics = diagnostics
end

function FileEntry:render_title()
	local padding = "  "

	local icon = ""

	if self.is_modified then
		icon = icon .. "● "
	end

	return padding .. icon .. self.name
end

return FileEntry
