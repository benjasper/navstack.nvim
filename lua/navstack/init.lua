local Config = require "navstack.config"
local Filestack = require "navstack.filestack"
local highlight = require "navstack.highlight"

---@class Navstack
---@field filestack Filestack
local M = {}

function M.toggle_sidebar()
	M.filestack:toggle_sidebar()
end

function M.open_sidebar()
	M.filestack:open_sidebar()
end

function M.close_sidebar()
	M.filestack:close_sidebar()
end

function M.jump_to(number)
	M.filestack:jump_to(number)
end

function M.jump_to_previous()
	M.filestack:jump_to_previous()
end

function M.jump_to_next()
	M.filestack:jump_to_next()
end

function M.clear()
	M.filestack:clear()
end

function M.toggle_pin()
	M.filestack:toggle_pin()
end

---@param customConfig Config | nil
function M.setup(customConfig)
	highlight.setup_highlights()

	local config = Config:create(customConfig)
	local filestack = Filestack:new(config)

	if config.persist_to_disk then
		filestack:load()
	end

	M.filestack = filestack

	filestack:register_autocommands()

	if config.sidebar.open_on_start then
		filestack:open_sidebar()
	end

	vim.api.nvim_create_user_command('NavstackToggle', function() filestack:toggle_sidebar() end, {})
	vim.api.nvim_create_user_command('NavstackOpen', function() filestack:open_sidebar() end, {})
	vim.api.nvim_create_user_command('NavstackClose', function() filestack:close_sidebar() end, {})
	vim.api.nvim_create_user_command('NavstackClear', function() filestack:clear() end, {})
end

return M