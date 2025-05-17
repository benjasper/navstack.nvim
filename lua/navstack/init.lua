local Config = require "navstack.config"

local M = {}

local FILE_TYPE = "navstack"

---@type number
M.sidebar_bufnr = -1

---@type number
M.sidebar_winid = -1

M.internal_jump = false

-- stack to hold opened file paths
---@type FileEntry[]
M.file_stack = {}

---@type Config
M.config = nil

function M.open_sidebar()
	-- If already open, don't open again
	if M.sidebar_winid and vim.api.nvim_win_is_valid(M.sidebar_winid) then
		vim.api.nvim_set_current_win(M.sidebar_winid)
		return
	end

	-- Save the current window to return focus later (optional)
	local current_win = vim.api.nvim_get_current_win()

	-- Create a new vertical split on the left
	-- vim.cmd('topleft vnew')
	vim.cmd('botright vnew')
	M.sidebar_winid = vim.api.nvim_get_current_win()
	M.sidebar_bufnr = vim.api.nvim_get_current_buf()

	-- Buffer options
	-- Set buffer options first, but leave modifiable = true for now
	vim.bo[M.sidebar_bufnr].buftype = 'nofile'
	vim.bo[M.sidebar_bufnr].bufhidden = 'wipe'
	vim.bo[M.sidebar_bufnr].swapfile = false
	vim.bo[M.sidebar_bufnr].filetype = FILE_TYPE
	vim.bo[M.sidebar_bufnr].bufhidden = 'hide'
	vim.bo[M.sidebar_bufnr].buflisted = false

	vim.api.nvim_buf_set_name(M.sidebar_bufnr, 'navstack://')

	-- Window options
	vim.wo[M.sidebar_winid].number = false
	vim.wo[M.sidebar_winid].relativenumber = false
	vim.wo[M.sidebar_winid].winfixwidth = true
	vim.wo[M.sidebar_winid].signcolumn = 'auto'
	vim.api.nvim_win_set_width(M.sidebar_winid, M.config.sidebar.width)

	-- Write content
	M.render_sidebar()

	-- Restore focus to original window
	vim.api.nvim_set_current_win(current_win)
end

function M.toggle_sidebar()
	if M.sidebar_winid and vim.api.nvim_win_is_valid(M.sidebar_winid) then
		vim.api.nvim_win_close(M.sidebar_winid, true)
		vim.api.nvim_buf_delete(M.sidebar_bufnr, { force = true })
		M.sidebar_winid = -1
		M.sidebar_bufnr = -1
	else
		M.open_sidebar()
	end
end

local ns = vim.api.nvim_create_namespace("navstack")

---@class FileEntry
---@field name string
---@field path string
---@field is_current boolean

function M.render_sidebar()
	if M.file_stack == nil then return end

	local buf = M.sidebar_bufnr

	-- Free the buffer to draw in
	vim.bo[M.sidebar_bufnr].modifiable = true

	-- Set the actual lines (one per entry)
	local lines = {}
	for _, entry in ipairs(M.file_stack) do
		local padding = "  "
		if entry.is_current then
			if M.config.sidebar.show_current then
				table.insert(lines, padding .. entry.name)
			end
		else
			table.insert(lines, padding .. entry.name)
		end
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Clear previous extmarks
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	for i, entry in ipairs(M.file_stack) do
		if entry.is_current then
			-- Add virtual lines for paths
			vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
				virt_lines = {
					{ { "  " .. entry.path, "Comment" } },
				},
				virt_lines_above = false,
			})

			vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
				virt_text = { { "→", "Special" } },
				virt_text_pos = 'overlay', -- so it appears inline before text
			})
		else
			-- Add virtual lines for paths
			vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
				virt_lines = {
					{ { "  " .. entry.path, "Comment" } },
				},
				virt_lines_above = false,
			})

			vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
				virt_text = { { tostring(i) .. ".", "Special" } },
				virt_text_pos = 'overlay', -- so it appears inline before text
			})
		end
	end

	-- Now lock the buffer
	vim.bo[M.sidebar_bufnr].modifiable = false

	vim.api.nvim_buf_set_keymap(M.sidebar_bufnr, "n", "<CR>", "", {
		noremap = true,
		silent = true,
		callback = function()
			M.open_entry_at_cursor()
		end,
	})
end

function M.jump_to_previous()
	if #M.file_stack <= 1 then
		return
	end

	local current_entry = 0
	for i, entry in ipairs(M.file_stack) do
		if entry.is_current then
			current_entry = i
			break
		end
	end
	if current_entry == 0 then
		return
	end

	local jump_to = current_entry - 1

	if current_entry == 1 then
		current_entry = #M.file_stack
	end

	M.open_entry(jump_to)
end

function M.jump_to_next()
	if #M.file_stack <= 1 then
		return
	end

	local current_entry = 0
	for i, entry in ipairs(M.file_stack) do
		if entry.is_current then
			current_entry = i
			break
		end
	end
	if current_entry == 0 then
		return
	end

	if current_entry == #M.file_stack then
		current_entry = 1
	end

	M.open_entry(current_entry + 1)
end

function M.on_buffer_enter()
	local full_path = vim.api.nvim_buf_get_name(0)
	vim.notify(full_path, vim.log.levels.INFO)

	local exclude_patterns = {
		"oil://*",
		"navstack://*",
	}

	if full_path == "" then
		return
	end

	local filename = vim.fn.fnamemodify(full_path, ":t")
	local relative_path = vim.fn.fnamemodify(full_path, ":.")

	-- Ignore files that match the exclude patterns
	for _, pattern in ipairs(exclude_patterns) do
		if vim.fn.match(full_path, pattern) ~= -1 then
			return
		end
	end

	if M.internal_jump then
		M.internal_jump = false

		-- Find out which file we're jumping to
		local jump_to = 0
		for i, entry in ipairs(M.file_stack) do
			entry.is_current = false

			if entry.path == relative_path and entry.name == filename then
				jump_to = i
				entry.is_current = true
			end
		end

		if jump_to > 0 then
			M.render_sidebar()
		end

		return
	end

	-- add filename at top of stack (avoid duplicates)
	for i, file in ipairs(M.file_stack) do
		if file.is_current then
			file.is_current = false
		end

		-- if its the same file don't add it again
		if file.name == filename and file.path == relative_path then
			table.remove(M.file_stack, i)
		end
	end

	table.insert(M.file_stack, 1, {
		name = filename,
		path = relative_path,
		is_current = true,
	})

	if M.sidebar_winid and vim.api.nvim_win_is_valid(M.sidebar_winid) then
		M.render_sidebar()
	end
end

---@param number number
function M.open_entry(number)
	M.internal_jump = true

	local entry = M.file_stack[number]
	if not entry then
		vim.notify("No file at number " .. number, vim.log.levels.WARN)
		return
	end

	if not entry then return end

	local fname = vim.fn.expand(entry.path) -- expand ~ to home

	-- Get window where sidebar is open
	-- We want to open file in the *other* window
	-- So get all windows and find one that isn't sidebar_win

	local wins = vim.api.nvim_list_wins()
	local target_win = -1
	for _, win in ipairs(wins) do
		if win ~= M.sidebar_winid and vim.api.nvim_win_get_buf(win) ~= M.sidebar_bufnr then
			target_win = win
			break
		end
	end

	-- Load or get buffer for file
	local buf_handle = vim.fn.bufnr(fname, true)

	-- Switch target window to that buffer
	vim.api.nvim_win_set_buf(target_win, buf_handle)

	-- Optionally focus target window
	vim.api.nvim_set_current_win(target_win)
end

function M.open_entry_at_cursor()
	local line = vim.api.nvim_win_get_cursor(0)[1] -- 1-based line under cursor

	M.open_entry(line)
end

function M.on_navstack_enter()
	vim.notify("on_navstack_enter", vim.log.levels.INFO)
	-- Next jump will be internal
	M.internal_jump = true
end

---@param customConfig Config | nil
function M.setup(customConfig)
	M.config = Config:create(customConfig)

	if M.config.sidebar.open_on_start then
		M.open_sidebar()
	end

	vim.api.nvim_create_user_command('NavstackToggle', M.toggle_sidebar, {})
	vim.api.nvim_create_user_command('NavstackOpen', M.open_sidebar, {})

	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = "*",
		callback = M.on_buffer_enter,
	})

	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = "navstack://*",
		callback = M.on_navstack_enter,
	})

	for i = 1, 9 do
		vim.keymap.set("n", "<leader>" .. tostring(i), function() M.open_entry(i) end, { noremap = true, silent = true })
	end

	vim.keymap.set("n", "<C-p>", function() M.jump_to_previous() end, { noremap = true, silent = true })
	vim.keymap.set("n", "<C-n>", function() M.jump_to_next() end, { noremap = true, silent = true })
end

return M
