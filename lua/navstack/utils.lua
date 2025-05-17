local M = {}

--- Check for an icon provider and return a common icon provider API
---@return fun(name: string, conf?: table<string, string>): string, string
local function get_icon_provider()
	-- prefer mini.icons
	local _, mini_icons = pcall(require, "mini.icons")
	---@diagnostic disable-next-line: undefined-field
	if _G.MiniIcons then -- `_G.MiniIcons` is a better check to see if the module is setup
		return function(name)
			return mini_icons.get("file", name)
		end
	end

	-- fallback to `nvim-web-devicons`
	local has_devicons, devicons = pcall(require, "nvim-web-devicons")
	if has_devicons then
		return function(name, conf)
			local icon, hl = devicons.get_icon(name)
			icon = icon or (conf and conf.default_file or "")
			return icon, hl
		end
	end

	return function()
		return "", "Comment"
	end
end

local icon_provider = get_icon_provider()

---@param name string
---@return string, string First element is the icon, second is the highlight group
function M.get_icon(name)
	return icon_provider(name)
end


return M
