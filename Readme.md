<div align="center">

# navstack.nvim

Easy shortcut navigation through your project with a stack of recently visited files.

https://github.com/user-attachments/assets/c4b1f694-5e26-42e3-8087-02b5bc76b2db

</div>

## ✨ Features
- Keeps a list of recently visited files for fast access that updates automatically as you navigate through your project
- Shows visited files in a vsplit
- New vistited files are added on top
- Open files by jumping directly to its stack position
- Iterate over your file history
- See which buffers have diagnostics or are still modified
- Persists history per cwd

## 👍🏻 Recommended workflow
- Jump to a specific file by pressing a key combination (e.g.: `<leader>2`)
- Iterate through the list with `<C-p>` and `<C-n>`
- Clear the list when you're working on a different part of your project

## Installation
Using lazy.nvim:
```lua
{
	dir = "benjasper/navstack.nvim",
	dependencies = {
		{ 'echasnovski/mini.icons', version = '*' }, -- or { 'nvim-tree/nvim-web-devicons', version = '*' }
	},
	config = function()
		local navstack = require("navstack")
		navstack.setup({
			--- override_config
		})

		-- Make your own keybindings:
		-- Map the keys to jump to a list entry, here it's <leader>1-9
		for i = 1, 9 do
			vim.keymap.set("n", "<leader>" .. tostring(i), function() navstack.jump_to(i) end, { noremap = true, silent = true })
		end

		-- Previous and next file
		vim.keymap.set("n", "<C-p>", function() navstack.jump_to_previous() end, { noremap = true, silent = true })
		vim.keymap.set("n", "<C-n>", function() navstack.jump_to_next() end, { noremap = true, silent = true })

		-- Toggle sidebar
		vim.keymap.set("n", "<leader>n", function() navstack.toggle_sidebar() end, { noremap = true, silent = true })

		-- Clear list
		vim.keymap.set("n", "<leader>cn", function() navstack.clear() end, { noremap = true, silent = true })
	end
}
```

You can find all the config options and their default values here: [config.lua](lua/navstack/config.lua)

## Concept
- Every file visit puts a list entry on top of the stack -> list of recently visited files
- You can jump to any file in the list, which will place it on top of the stack again
- You can iterate over the stack, which won't trigger a change in the list
Differences to the jumplist:
- Doesn't replace the jumplist, but compliments it by allowing you to jump directly to a file
- Doesn't track file positions like the jumplist, only files

## Roadmap
- [x] Prev and next file
- [x] Ignore files outside cwd
- [x] Open buffer in current window
- [x] Diagnostic marker
- [x] File modified marker
- [x] Better filetype exclusion
- [x] Max length of stack
- [x] Save list to disk per cwd
- [x] Clear list
- [x] Icon support
- [ ] Auto resize sidebar
- [ ] Custom highlight groups
- [ ] Git support
- [ ] Pin buffer to specific number
- [ ] Support for deleted / moved / renamed files (Maybe when 'file-change detection' is implemented https://neovim.io/roadmap/)
