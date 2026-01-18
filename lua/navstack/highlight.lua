local M = {}

local function maybe_link(group, target)
	local ok, existing = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
	if not ok or vim.tbl_isempty(existing) then
		vim.api.nvim_set_hl(0, group, { link = target, bg = nil })
	end
end

function M.setup_highlights()
	maybe_link("NavstackPinned", "Special")
	maybe_link("NavstackIndex", "Normal")
	maybe_link("NavstackCurrent", "Special")
	maybe_link("NavstackPath", "Comment")
	maybe_link("NavstackTabLine", "TabLine")
	maybe_link("NavstackTabLineSel", "TabLineSel")
end

vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("NavstackHighlightReload", { clear = true }),
	callback = function()
		vim.schedule(M.setup_highlights)
	end,
})

return M