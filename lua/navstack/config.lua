---@class Config
---@field sidebar SidebarConfig
---@field cwd_only boolean Keep only entries that are in the current working directory
---@field direct_jump_as_new_entry boolean When jumping to a file with open_file, add it to the stack as a new entry, otherwise keep the stack as is
---@field quit_when_last_window boolean Whether to quit when navstack detects the sidebar is the only window left

---@class SidebarConfig
---@field align "left" | "right"
---@field width number
---@field open_on_start boolean Whether to open the sidebar on startup

Config = {
	sidebar = {
		align = "right",
		width = 50,
		open_on_start = false,
	},
	cwd_only = true,
	direct_jump_as_new_entry = true,
	quit_when_last_window = false,
}

---@param custom Config | nil
function Config:create(custom)
	return vim.tbl_deep_extend("force", Config, custom or {})
end

return Config
