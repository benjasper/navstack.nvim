FileEntry = require "navstack.file_entry"

---@class Filestack
---@field config Config
---@field sidebar_bufnr number
---@field sidebar_winid number
---@field internal_jump boolean
---@field file_stack FileEntry[]
Filestack = {}

local FILE_TYPE = "navstack"
local ns = vim.api.nvim_create_namespace("navstack")

local DIAGNOSTIC_SIGNS = {
	[vim.diagnostic.severity.ERROR] = "󰅚 ",
	[vim.diagnostic.severity.WARN] = "󰀪 ",
	[vim.diagnostic.severity.INFO] = "󰋽 ",
	[vim.diagnostic.severity.HINT] = "󰌶 ",
}

local DIAGNOSTIC_HIGHLIGHTS = {
	[vim.diagnostic.severity.ERROR] = "DiagnosticError",
	[vim.diagnostic.severity.WARN] = "DiagnosticWarn",
	[vim.diagnostic.severity.INFO] = "DiagnosticInfo",
	[vim.diagnostic.severity.HINT] = "DiagnosticHint",
}

---@param config Config
---@return Filestack
function Filestack:new(config)
	local obj = { config = config, sidebar_bufnr = -1, sidebar_winid = -1, internal_jump = false, file_stack = {} }
	setmetatable(obj, self)
	self.__index = self
	return obj
end

function Filestack:open_sidebar()
	-- If already open, just switch to it
	if self.sidebar_winid and vim.api.nvim_win_is_valid(self.sidebar_winid) then
		vim.api.nvim_set_current_win(self.sidebar_winid)
		return
	end

	-- Save the current window to return focus later
	local current_win = vim.api.nvim_get_current_win()

	-- Create or reuse buffer
	if not self.sidebar_bufnr or not vim.api.nvim_buf_is_valid(self.sidebar_bufnr) then
		self.sidebar_bufnr = vim.api.nvim_create_buf(false, true) -- [listed = false, scratch = true]
	end

	-- Setup buffer options
	vim.bo[self.sidebar_bufnr].buftype = 'nofile'
	vim.bo[self.sidebar_bufnr].bufhidden = 'hide'
	vim.bo[self.sidebar_bufnr].swapfile = false
	vim.bo[self.sidebar_bufnr].filetype = FILE_TYPE
	vim.bo[self.sidebar_bufnr].buflisted = false
	vim.api.nvim_buf_set_name(self.sidebar_bufnr, 'navstack://')

	-- Create window (non-floating, anchored to side like vsplit)
	self.sidebar_winid = vim.api.nvim_open_win(self.sidebar_bufnr, false, {
		split = self.config.sidebar.align,
		width = self.config.sidebar.width,
	})

	-- Setup window options
	vim.wo[self.sidebar_winid].number = false
	vim.wo[self.sidebar_winid].relativenumber = false
	vim.wo[self.sidebar_winid].winfixwidth = true
	vim.wo[self.sidebar_winid].signcolumn = 'auto'

	-- Write content
	self:render_sidebar()

	-- Keybindings
	vim.keymap.set("n", "<CR>", function()
		self:open_entry_at_cursor()
	end, { buffer = self.sidebar_bufnr, silent = true, noremap = true })

	vim.keymap.set("n", "q", function()
		self:close_sidebar()
	end, { buffer = self.sidebar_bufnr, silent = true, noremap = true })

	-- Return focus
	vim.api.nvim_set_current_win(current_win)
end

function Filestack:close_sidebar()
	if not self.sidebar_winid or not vim.api.nvim_win_is_valid(self.sidebar_winid) then
		return
	end

	-- Close the window and delete the buffer
	vim.api.nvim_win_close(self.sidebar_winid, true)

	if self.sidebar_bufnr and vim.api.nvim_buf_is_valid(self.sidebar_bufnr) then
		vim.api.nvim_buf_delete(self.sidebar_bufnr, { force = true })
	end

	-- Reset state
	self.sidebar_winid = nil
end

function Filestack:toggle_sidebar()
	if self.sidebar_winid and vim.api.nvim_win_is_valid(self.sidebar_winid) then
		self:close_sidebar()
	else
		self:open_sidebar()
	end
end

function Filestack:render_sidebar()
	if self.file_stack == nil or self.sidebar_bufnr == -1 or not vim.api.nvim_buf_is_valid(self.sidebar_bufnr) then return end

	-- Free the buffer to draw in
	vim.bo[self.sidebar_bufnr].modifiable = true

	-- Set the actual lines (one per entry)
	local lines = {}
	for _, entry in ipairs(self.file_stack) do
		local line = entry:render_title()

		table.insert(lines, line)
	end

	vim.api.nvim_buf_set_lines(self.sidebar_bufnr, 0, -1, false, lines)

	-- Clear previous extmarks
	vim.api.nvim_buf_clear_namespace(self.sidebar_bufnr, ns, 0, -1)

	for i, entry in ipairs(self.file_stack) do
		local offset = 0
		if entry.is_modified then
			offset = 3
		end

		vim.api.nvim_buf_set_extmark(self.sidebar_bufnr, ns, i - 1, 2 + offset, {
			end_col = 4 + offset,
			hl_group = entry.icon_hl,
		})

		-- Add virtual lines for paths
		vim.api.nvim_buf_set_extmark(self.sidebar_bufnr, ns, i - 1, 0, {
			virt_lines = {
				{ { "  " .. entry.path, "Comment" } },
			},
			virt_lines_above = false,
		})

		if entry.is_current then
			vim.api.nvim_buf_set_extmark(self.sidebar_bufnr, ns, i - 1, 0, {
				virt_text = { { "→ ", "Special" } },
				virt_text_pos = 'overlay', -- so it appears inline before text
			})
		else
			vim.api.nvim_buf_set_extmark(self.sidebar_bufnr, ns, i - 1, 0, {
				virt_text = { { tostring(i), "Special" } },
				virt_text_pos = 'overlay', -- so it appears inline before text
			})
		end

		for severity, count in pairs(entry.diagnostics) do
			vim.api.nvim_buf_set_extmark(self.sidebar_bufnr, ns, i - 1, 0, {
				virt_text = { { DIAGNOSTIC_SIGNS[severity] .. count, DIAGNOSTIC_HIGHLIGHTS[severity] } },
				virt_text_pos = 'eol',
			})
		end

		if entry.is_temporary then
			vim.api.nvim_buf_set_extmark(self.sidebar_bufnr, ns, i - 1, 2, {
				end_line = i,
				hl_group = "Comment",
				hl_eol = true, -- highlight to the end of line
			})
		end
	end

	-- Now lock the buffer
	vim.bo[self.sidebar_bufnr].modifiable = false
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

	self:jump_to(jump_to, true)
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

	self:jump_to(jump_to, true)
end

---@param bufnr number
function Filestack:is_real_file_buffer(bufnr)
	-- Ignore unloaded buffers
	if not vim.api.nvim_buf_is_loaded(bufnr) then return false end

	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == '' then return false end

	-- Use vim.bo[bufnr] instead of deprecated API
	local buftype = vim.bo[bufnr].buftype
	if buftype ~= "" then return false end

	local filetype = vim.bo[bufnr].filetype

	if self.config.ignored_filetypes[filetype] then return false end

	-- Final check: is this a real file on disk?
	local stat = vim.uv.fs_stat(name)
	return stat and stat.type == "file"
end

---@param filepath string
function Filestack:is_in_cwd(filepath)
	local cwd = vim.fn.getcwd()
	local normalized_cwd = vim.fs.normalize(cwd)
	local normalized_path = vim.fs.normalize(filepath)

	return normalized_path:sub(1, #normalized_cwd) == normalized_cwd
end

function Filestack:on_buffer_enter()
	local full_path = vim.api.nvim_buf_get_name(0)
	local bufnr = vim.api.nvim_get_current_buf()

	local exclude_patterns = {
		"oil://*",
		"navstack://*",
	}

	if full_path == "" or not self:is_real_file_buffer(bufnr) then
		return
	end

	local filename = vim.fn.fnamemodify(full_path, ":t")
	local relative_path = vim.fn.fnamemodify(full_path, ":.:h")

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

			if entry.full_path == full_path then
				jump_to = i
				entry.is_current = true
			end
		end

		if jump_to > 0 then
			self:render_sidebar()
		end

		return
	end

	-- if we find the file we can just move it
	local found_file = nil

	-- search for files that should be removed from the stack
	for i = #self.file_stack, 1, -1 do
		local file = self.file_stack[i]

		if file.is_current then
			file.is_current = false
		end

		if file.full_path == full_path then
			found_file = file
		end

		if file.is_temporary or file.full_path == full_path then
			table.remove(self.file_stack, i)
		end
	end

	local is_temporary = self.config.cwd_only and not self:is_in_cwd(full_path)

	---@type FileEntry | nil
	local new_entry = nil

	if found_file then
		found_file.is_current = true
		new_entry = found_file
	else
		new_entry = FileEntry:new(
			filename,
			relative_path,
			true,
			is_temporary,
			full_path
		)
	end

	table.insert(self.file_stack, 1, new_entry)

	-- Remove entries that are over the limit
	while #self.file_stack > self.config.max_files do
		table.remove(self.file_stack) -- removes last element by default
	end

	-- Persist asynchronously
	if self.config.persist_to_disk then
		vim.schedule(function()
			self:persist()
		end)
	end

	if self.sidebar_winid and vim.api.nvim_win_is_valid(self.sidebar_winid) then
		self:render_sidebar()
	end
end

local function get_temp_file_path(name)
	local temp_dir = vim.fn.stdpath("cache")
	local cwd = vim.fn.getcwd()
	local hash = vim.fn.sha256(cwd):sub(1, 16) -- shorten for path friendliness
	local dir = temp_dir .. "/navstack/" .. hash
	vim.fn.mkdir(dir, "p")
	return dir .. "/" .. name
end

function Filestack:persist()
	local file_path = get_temp_file_path("files.json")

	local serialized_files = {}

	for _, file_entry in ipairs(self.file_stack) do
		table.insert(serialized_files, file_entry:serialize())
	end

	local contents = vim.json.encode(serialized_files)

	local f = io.open(file_path, "w")
	if not f then
		vim.notify("Failed to open file for writing: " .. file_path, vim.log.levels.ERROR)
		return
	end

	f:write(contents)
	f:close()
end

function Filestack:load()
	local file_path = get_temp_file_path("files.json")
	if not vim.uv.fs_stat(file_path) then
		return
	end

	local f = io.open(file_path, "r")
	if not f then
		vim.notify("Failed to open file for reading: " .. file_path, vim.log.levels.ERROR)
		return
	end

	local contents = f:read("*a")
	f:close()

	local deserialized_files = vim.json.decode(contents)

	for _, file_entry in ipairs(deserialized_files) do
		local full_path = file_entry.full_path
		local new_entry = FileEntry:new(
			vim.fn.fnamemodify(full_path, ":t"),
			vim.fn.fnamemodify(full_path, ":.:h"),
			false,
			file_entry.is_temporary,
			full_path
		)

		table.insert(self.file_stack, new_entry)
	end
end

---@param number number
---@param force_internal_jump boolean | nil
---@param target_win number | nil
function Filestack:jump_to(number, force_internal_jump, target_win)
	if not self.config.direct_jump_as_new_entry or force_internal_jump then
		self.internal_jump = true
	end

	local entry = self.file_stack[number]
	if not entry then
		vim.notify("No file at number " .. number, vim.log.levels.WARN)
		return
	end

	if not entry then return end

	local fname = vim.fn.expand(entry.full_path) -- expand ~ to home

	-- Get window where sidebar is open
	-- We want to open file in the *other* window
	-- So get all windows and find one that isn't sidebar_win

	if not target_win then
		target_win = vim.api.nvim_get_current_win()
	end

	-- Load or get buffer for file
	local buf_handle = vim.fn.bufnr(fname, true)

	-- Switch target window to that buffer
	vim.api.nvim_win_set_buf(target_win, buf_handle)

	if vim.api.nvim_get_current_win() ~= target_win then
		vim.api.nvim_set_current_win(target_win)
	end
end

function Filestack:clear()
	self.file_stack = {}
	self:persist()
	self:render_sidebar()
end

function Filestack:open_entry_at_cursor()
	-- Find main window
	local wins = vim.api.nvim_list_wins()
	local found_win = -1
	for _, win in ipairs(wins) do
		if win ~= self.sidebar_winid and vim.api.nvim_win_get_buf(win) ~= self.sidebar_bufnr then
			found_win = win
			break
		end
	end

	local line = vim.api.nvim_win_get_cursor(0)[1] -- 1-based line under cursor

	self:jump_to(line, nil, found_win)
end

function Filestack:on_navstack_enter()
	if not self.config.quit_when_last_window then
		return
	end

	-- Get all listed windows (ignores floating/unlisted)
	local wins = vim.api.nvim_list_wins()
	local sidebar_winid = self.sidebar_winid
	if #wins == 1 and wins[1] == sidebar_winid then
		local buf = vim.api.nvim_win_get_buf(sidebar_winid)
		local ft = vim.bo[buf].filetype
		if ft == FILE_TYPE then
			vim.cmd("quit")
		end
	end
end

---@param bufnr number
function Filestack:on_buffer_modified(bufnr)
	local modified = vim.bo[bufnr].modified
	local full_path = vim.api.nvim_buf_get_name(bufnr)

	-- Find out if the file is in the stack
	for _, entry in ipairs(self.file_stack) do
		if entry.full_path == full_path then
			entry.is_modified = modified

			self:render_sidebar()
			break
		end
	end
end

function Filestack:on_diagnostic_changed(bufnr)
	local foundEntry = nil
	-- Find the file entry for the current buffer
	for _, entry in ipairs(self.file_stack) do
		if entry.full_path == vim.api.nvim_buf_get_name(bufnr) then
			foundEntry = entry
			break
		end
	end

	if not foundEntry then
		return
	end

	local diagnostics = vim.diagnostic.get(bufnr)

	---@type table<vim.diagnostic.Severity, integer>
	local diagnosticsTable = {}

	for _, d in ipairs(diagnostics) do
		if diagnosticsTable[d.severity] == nil then
			diagnosticsTable[d.severity] = 0
		end
		diagnosticsTable[d.severity] = diagnosticsTable[d.severity] + 1
	end

	foundEntry:set_diagnostics(diagnosticsTable)

	self:render_sidebar()
end

function Filestack:on_file_deleted(file_path)
	for i, entry in ipairs(self.file_stack) do
		if entry.full_path == file_path then
			table.remove(self.file_stack, i)
			self:render_sidebar()
			break
		end
	end
end

function Filestack:register_autocommands()
	local group = vim.api.nvim_create_augroup("Navstack", { clear = true })

	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = "*",
		callback = function() self:on_buffer_enter() end,
		group = group,
	})

	vim.api.nvim_create_autocmd("WinEnter", {
		pattern = "navstack://*",
		callback = function() self:on_navstack_enter() end,
	})

	vim.api.nvim_create_autocmd("BufModifiedSet", {
		callback = function(args)
			local bufnr = args.buf
			self:on_buffer_modified(bufnr)
		end,
		group = group,
	})

	vim.api.nvim_create_autocmd("BufWritePost", {
		callback = function(args)
			local bufnr = args.buf
			self:on_buffer_modified(bufnr)
		end,
		group = group,
	})

	vim.api.nvim_create_autocmd("DiagnosticChanged", {
		group = group,
		callback = function(args)
			local bufnr = args.buf
			self:on_diagnostic_changed(bufnr)
		end,
	})
end

return Filestack