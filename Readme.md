# Navstack

Easy shortcut navigation through your project with a stack of recently visited files.

## Workflow
- Keeps a list of recently visited files for fast access that updates automatically as you navigate through your project
- Jump to a specific file by pressing a key combination (e.g.: `<leader>2`)
- Iterate through the list with `<C-p>` and `<C-n>`
- Clear the list when you're working on a different part of your project

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
