---@class FileEntry
---@field name string
---@field path string
---@field is_current boolean
---@field is_temporary boolean
local FileEntry = {}

---@param name string
---@param path string
---@param is_current boolean
---@param is_temporary boolean
function FileEntry:new(name, path, is_current, is_temporary)
	local obj = { name = name, path = path, is_current = is_current, is_temporary = is_temporary }
	setmetatable(obj, self)
	self.__index = self
	return obj
end

return FileEntry

