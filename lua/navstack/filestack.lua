FileEntry = require "navstack.file_entry"

---@class Filestack
---@field config Config
---@field sidebar_bufnr number
---@field sidebar_winid number
---@field internal_jump boolean
---@field file_stack FileEntry[]
Filestack = {}

local FILE_TYPE = "navstack"

---@param config Config
---@return Filestack
function Filestack:new(config)
	local obj = { config = config, sidebar_bufnr = -1, sidebar_winid = -1, internal_jump = false, file_stack = {} }
	setmetatable(obj, self)
	self.__index = self
	return obj
end

function Filestack:open_sidebar()
	-- If already open, don't open again
	if self.sidebar_winid and vim.api.nvim_win_is_valid(self.sidebar_winid) then
		vim.api.nvim_set_current_win(self.sidebar_winid)
		return
	end

	-- Save the current window to return focus later (optional)
	local current_win = vim.api.nvim_get_current_win()

	-- Create a new vertical split on the left
	-- vim.cmd('topleft vnew')
	vim.cmd('botright vnew')
	self.sidebar_winid = vim.api.nvim_get_current_win()
	self.sidebar_bufnr = vim.api.nvim_get_current_buf()

	-- Buffer options
	-- Set buffer options first, but leave modifiable = true for now
	vim.bo[self.sidebar_bufnr].buftype = 'nofile'
	vim.bo[self.sidebar_bufnr].bufhidden = 'wipe'
	vim.bo[self.sidebar_bufnr].swapfile = false
	vim.bo[self.sidebar_bufnr].filetype = FILE_TYPE
	vim.bo[self.sidebar_bufnr].bufhidden = 'hide'
	vim.bo[self.sidebar_bufnr].buflisted = false

	vim.api.nvim_buf_set_name(self.sidebar_bufnr, 'navstack://')

	-- Window options
	vim.wo[self.sidebar_winid].number = false
	vim.wo[self.sidebar_winid].relativenumber = false
	vim.wo[self.sidebar_winid].winfixwidth = true
	vim.wo[self.sidebar_winid].signcolumn = 'auto'
	vim.api.nvim_win_set_width(self.sidebar_winid, self.config.sidebar.width)

	-- Write content
	self:render_sidebar()

	-- Restore focus to original window
	vim.api.nvim_set_current_win(current_win)
end

function Filestack:toggle_sidebar()
	if self.sidebar_winid and vim.api.nvim_win_is_valid(self.sidebar_winid) then
		vim.api.nvim_win_close(self.sidebar_winid, true)
		vim.api.nvim_buf_delete(self.sidebar_bufnr, { force = true })
		self.sidebar_winid = -1
		self.sidebar_bufnr = -1
	else
		self:open_sidebar()
	end
end

local ns = vim.api.nvim_create_namespace("navstack")

function Filestack:render_sidebar()
	if self.file_stack == nil then return end

	local buf = self.sidebar_bufnr

	-- Free the buffer to draw in
	vim.bo[self.sidebar_bufnr].modifiable = true

	-- Set the actual lines (one per entry)
	local lines = {}
	for _, entry in ipairs(self.file_stack) do
		local padding = "  "
		if entry.is_current then
			if self.config.sidebar.show_current then
				table.insert(lines, padding .. entry.name)
			end
		else
			table.insert(lines, padding .. entry.name)
		end
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- Clear previous extmarks
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	for i, entry in ipairs(self.file_stack) do
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
	vim.bo[self.sidebar_bufnr].modifiable = false

	vim.api.nvim_buf_set_keymap(self.sidebar_bufnr, "n", "<CR>", "", {
		noremap = true,
		silent = true,
		callback = function()
			self:open_entry_at_cursor()
		end,
	})
end

function Filestack:jump_to_next()
	if #self.file_stack <= 1 then
		return
	end

	local current_entry = 0
	for i, entry in ipairs(self.file_stack) do
		if entry.is_current then
			current_entry = i
			break
		end
	end
	if current_entry == 0 then
		return
	end

	local jump_to = current_entry - 1

	if jump_to == 0 then
		jump_to = #self.file_stack
	end

	self:open_entry(jump_to)
end

function Filestack:jump_to_previous()
	if #self.file_stack <= 1 then
		return
	end

	local current_entry = 0
	for i, entry in ipairs(self.file_stack) do
		if entry.is_current then
			current_entry = i
			break
		end
	end
	if current_entry == 0 then
		return
	end

	local jump_to = current_entry + 1

	if jump_to > #self.file_stack then
		jump_to = 1
	end

	self:open_entry(jump_to)
end

local function is_real_file_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local buftype = vim.bo[bufnr].buftype
	local name = vim.api.nvim_buf_get_name(bufnr)
	local listed = vim.fn.buflisted(bufnr) == 1

	return listed and buftype == "" and name ~= ""
end

function Filestack:on_buffer_enter()
	local full_path = vim.api.nvim_buf_get_name(0)

	local exclude_patterns = {
		"oil://*",
		"navstack://*",
	}

	if full_path == "" or not is_real_file_buffer() then
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

	if self.internal_jump then
		self.internal_jump = false

		-- Find out which file we're jumping to
		local jump_to = 0
		for i, entry in ipairs(self.file_stack) do
			entry.is_current = false

			if entry.path == relative_path and entry.name == filename then
				jump_to = i
				entry.is_current = true
			end
		end

		if jump_to > 0 then
			self:render_sidebar()
		end

		return
	end

	-- add filename at top of stack (avoid duplicates)
	for i, file in ipairs(self.file_stack) do
		if file.is_current then
			file.is_current = false
		end

		-- if its the same file don't add it again
		if file.name == filename and file.path == relative_path then
			table.remove(self.file_stack, i)
		end
	end

	table.insert(self.file_stack, 1, FileEntry:new(filename, relative_path, true, false))

	if self.sidebar_winid and vim.api.nvim_win_is_valid(self.sidebar_winid) then
		self:render_sidebar()
	end
end

---@param number number
function Filestack:open_entry(number)
	self.internal_jump = true

	local entry = self.file_stack[number]
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
		if win ~= self.sidebar_winid and vim.api.nvim_win_get_buf(win) ~= self.sidebar_bufnr then
			target_win = win
			break
		end
	end

	-- Load or get buffer for file
	local buf_handle = vim.fn.bufnr(fname, true)

	-- Switch target window to that buffer
	vim.api.nvim_win_set_buf(target_win, buf_handle)
end

function Filestack:open_entry_at_cursor()
	local line = vim.api.nvim_win_get_cursor(0)[1] -- 1-based line under cursor

	self:open_entry(line)
end

function Filestack:on_navstack_enter()
	-- Next jump will be internal
	self.internal_jump = true
end

return Filestack
