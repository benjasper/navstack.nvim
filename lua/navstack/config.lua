---@class Config
---@field sidebar SidebarConfig
---@field cwd_only boolean Keep only entries that are in the current working directory
---@field ignore_gitignored boolean Ignore files that are ignored by .gitignore
---@field direct_jump_as_new_entry boolean When jumping to a file with open_file, add it to the stack as a new entry, otherwise keep the stack as is
---@field insert_mode_on_top boolean When entering insert mode and the file is not on top of the stack, add it to the top
---@field quit_when_last_window boolean Whether to quit when navstack detects the sidebar is the only window left
---@field max_files number Maximum number of files to keep in the stack
---@field ignored_filetypes table<string, boolean> Filetypes to ignore
---@field persist_to_disk boolean Whether to persist the stack to disk, it's saved in the cache directory per cwd
---@field window_float vim.api.keyset.win_config Config for the floating window
---@field win_type "sidebar" | "float" | "tabline" Type of window to use
---@field tabline_config TabLineConfig

---@class SidebarConfig
---@field align "left" | "right"
---@field width number
---@field open_on_start boolean Whether to open the sidebar on startup

---@class TabLineConfig
---@field separator string
---@field left_padding string

Config = {
	win_type = "sidebar",
	sidebar = {
		align = "right",
		width = 50,
		open_on_start = false,
	},
	cwd_only = true,
	ignore_gitignored = true,
	direct_jump_as_new_entry = true,
	insert_mode_on_top = true,
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
	window_float = {
		relative = "editor",
		width = 40,
		height = 20,
		style = "minimal",
		border = "rounded",
	},
	tabline_config = {
		separator = "│",
		left_padding = "",
	},
}

---@param custom Config | nil
function Config:create(custom)
	return vim.tbl_deep_extend("force", Config, custom or {})
end

return Config