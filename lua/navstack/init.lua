local M = {}

---@type number
local sidebar_bufnr = -1

---@type number
local sidebar_winid = -1

-- stack to hold opened file paths
M.file_stack = {}

---@class Config
---@field sidebar SidebarConfig

---@class SidebarConfig
---@field width number
---@field show_current boolean Whether to show the current file in the sidebar
---@field open_on_start boolean Whether to open the sidebar on startup

---@type Config
M.config = {
	sidebar = {
		width = 50,
		show_current = true,
		open_on_start = false,
	}
}

function M.open_sidebar()
	-- If already open, don't open again
	if sidebar_winid and vim.api.nvim_win_is_valid(sidebar_winid) then
		vim.api.nvim_set_current_win(sidebar_winid)
		return
	end

	-- Save the current window to return focus later (optional)
	local current_win = vim.api.nvim_get_current_win()

	-- Create a new vertical split on the left
	-- vim.cmd('topleft vnew')
	vim.cmd('botright vnew')
	sidebar_winid = vim.api.nvim_get_current_win()
	sidebar_bufnr = vim.api.nvim_get_current_buf()

	-- Buffer options
	-- Set buffer options first, but leave modifiable = true for now
	vim.bo[sidebar_bufnr].buftype = 'nofile'
	vim.bo[sidebar_bufnr].bufhidden = 'wipe'
	vim.bo[sidebar_bufnr].swapfile = false
	vim.bo[sidebar_bufnr].filetype = 'mysidebar'
	vim.bo[sidebar_bufnr].bufhidden = 'hide'
	vim.bo[sidebar_bufnr].buflisted = false

	vim.api.nvim_buf_set_name(sidebar_bufnr, 'sidebar://sidebar')

	-- Window options
	vim.wo[sidebar_winid].number = false
	vim.wo[sidebar_winid].relativenumber = false
	vim.wo[sidebar_winid].winfixwidth = true
	vim.wo[sidebar_winid].signcolumn = 'auto'
	vim.api.nvim_win_set_width(sidebar_winid, M.config.sidebar.width)

	-- Write content
	M.render_sidebar(M.file_stack)

	-- Restore focus to original window
	vim.api.nvim_set_current_win(current_win)
end

function M.toggle_sidebar()
	if sidebar_winid and vim.api.nvim_win_is_valid(sidebar_winid) then
		vim.api.nvim_win_close(sidebar_winid, true)
		sidebar_winid = -1
		sidebar_bufnr = -1
	else
		M.open_sidebar()
	end
end

local ns = vim.api.nvim_create_namespace("mysidebar")

function M.render_sidebar(entries)
	local buf = sidebar_bufnr

	-- Free the buffer to draw in
	vim.bo[sidebar_bufnr].modifiable = true

	-- Set the actual lines (one per entry)
	local lines = {}
	for i, entry in ipairs(entries) do
		local padding = "  "
		if i == 1 then
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

	for i, entry in ipairs(entries) do
		if i == 1 then
			-- Add virtual lines for paths
			vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
				virt_lines = {
					{ { "  " .. entry.path, "Comment" } },
				},
				virt_lines_above = false,
			})

			vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
				virt_text = { { "→" , "Special" } },
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
				virt_text = { { tostring(i - 1) .. ".", "Special" } },
				virt_text_pos = 'overlay', -- so it appears inline before text
			})
		end
	end

	-- Now lock the buffer
	vim.bo[sidebar_bufnr].modifiable = false

	vim.api.nvim_buf_set_keymap(sidebar_bufnr, "n", "<CR>", "", {
		noremap = true,
		silent = true,
		callback = function()
			M.open_entry_at_cursor()
		end,
	})
end

function M.on_file_open()
	local exclude_patterns = {
		"oil://*",
		"sidebar://*",
	}

	local full_path = vim.api.nvim_buf_get_name(0)

	-- Ignore files that match the exclude patterns
	for _, pattern in ipairs(exclude_patterns) do
		if vim.fn.match(full_path, pattern) ~= -1 then
			return
		end
	end

	if full_path ~= "" then
		local filename = vim.fn.fnamemodify(full_path, ":t")
		local relative_path = vim.fn.fnamemodify(full_path, ":.")

		-- add filename at top of stack (avoid duplicates)
		for i, v in ipairs(M.file_stack) do
			-- if its the same file don't add it again
			if i == 1 and v.name == filename and v.path == relative_path then
				return
			end

			if v.name == filename and v.path == relative_path then
				table.remove(M.file_stack, i)
				break
			end
		end

		table.insert(M.file_stack, 1, {
			name = filename,
			path = relative_path,
		})

		if sidebar_winid and vim.api.nvim_win_is_valid(sidebar_winid) then
			M.render_sidebar(M.file_stack)
		end
	end
end

function M.open_entry(number)
	local entry = M.file_stack[number + 1]
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
		if win ~= sidebar_winid and vim.api.nvim_win_get_buf(win) ~= sidebar_bufnr then
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
	if M.config.sidebar.show_current then
		line = line - 1
	end

	M.open_entry(line)
end

---@param config Config | nil
function M.setup(config)
	M.config = vim.tbl_deep_extend("force", M.config, config or {})

	if M.config.sidebar.open_on_start then
		M.open_sidebar()
	end

	vim.api.nvim_create_user_command('SidebarToggle', M.toggle_sidebar, {})
	vim.api.nvim_create_user_command('SidebarOpen', M.open_sidebar, {})

	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = "*",
		callback = M.on_file_open,
	})

	for i = 1, 9 do
		vim.keymap.set("n", "<leader>" .. tostring(i), function() M.open_entry(i) end, { noremap = true, silent = true })
	end
end

return M
