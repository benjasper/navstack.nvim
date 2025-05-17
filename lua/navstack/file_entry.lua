---@class FileEntry
---@field name string
---@field path string
---@field full_path string
---@field is_current boolean
---@field is_temporary boolean
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
		full_path = full_path
	}

	setmetatable(obj, self)
	self.__index = self
	return obj
end

return FileEntry
