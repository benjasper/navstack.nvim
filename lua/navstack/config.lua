---@class Config
---@field sidebar SidebarConfig
---@field cwd_only boolean Keep only entries that are in the current working directory
---@field ignore_gitignored boolean Ignore files that are ignored by .gitignore
---@field direct_jump_as_new_entry boolean When jumping to a file with open_file, add it to the stack as a new entry, otherwise keep the stack as is
---@field quit_when_last_window boolean Whether to quit when navstack detects the sidebar is the only window left
---@field max_files number Maximum number of files to keep in the stack
---@field ignored_filetypes table<string, boolean> Filetypes to ignore
---@field persist_to_disk boolean Whether to persist the stack to disk, it's saved in the cache directory per cwd

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
	ignore_gitignored = true,
	direct_jump_as_new_entry = true,
	quit_when_last_window = false,
	max_files = 9,
	persist_to_disk = true,
	ignored_filetypes = {
		["neo-tree"] = true,
		["neotree"] = true,
		["gitcommit"] = true,
		["NeogitStatus"] = true,
		["oil"] = true,
		["help"] = true,
		["nofile"] = true,
	},
}

---@param custom Config | nil
function Config:create(custom)
	return vim.tbl_deep_extend("force", Config, custom or {})
end

return Config