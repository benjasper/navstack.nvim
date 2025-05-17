---@class Config
---@field sidebar SidebarConfig

---@class SidebarConfig
---@field align "left" | "right"
---@field width number
---@field show_current boolean Whether to show the current file in the sidebar
---@field open_on_start boolean Whether to open the sidebar on startup

Config = {
	sidebar = {
		align = "right",
		width = 50,
		show_current = true,
		open_on_start = false,
	}
}

---@param custom Config | nil
function Config:create (custom)
	return vim.tbl_deep_extend("force", Config, custom or {})
end

return Config
