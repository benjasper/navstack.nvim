local Config = require "navstack.config"
local Filestack = require "navstack.filestack"

---@class Navstack
---@field filestack Filestack
local M = {}

function M.toggle_sidebar()
	M.filestack:toggle_sidebar()
end

function M.open_sidebar()
	M.filestack:open_sidebar()
end

function M.open_entry(number)
	M.filestack:open_entry(number)
end

function M.jump_to_previous()
	M.filestack:jump_to_previous()
end

function M.jump_to_next()
	M.filestack:jump_to_next()
end

---@param customConfig Config | nil
function M.setup(customConfig)
	local config = Config:create(customConfig)
	local filestack = Filestack:new(config)
	M.filestack = filestack

	if config.sidebar.open_on_start then
		filestack:open_sidebar()
	end

	vim.api.nvim_create_user_command('NavstackToggle', function() filestack:toggle_sidebar() end, {})
	vim.api.nvim_create_user_command('NavstackOpen', function() filestack:open_sidebar() end, {})

	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = "*",
		callback = function() filestack:on_buffer_enter() end,
	})

	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = "navstack://*",
		callback = function() filestack:on_navstack_enter() end,
	})

	for i = 1, 9 do
		vim.keymap.set("n", "<leader>" .. tostring(i), function() filestack:open_entry(i) end, { noremap = true, silent = true })
	end

	vim.keymap.set("n", "<C-p>", function() filestack:jump_to_previous() end, { noremap = true, silent = true })
	vim.keymap.set("n", "<C-n>", function() filestack:jump_to_next() end, { noremap = true, silent = true })
end

return M
