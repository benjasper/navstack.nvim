# Navstack

## Workflow
- Keeps a list of recently visited files for fast access that updates automatically as you navigate through your project
- Jump to a specific file by pressing a number
- Iterate through the list with `<C-p>` and `<C-n>`
- Clear the list when you're working on a different part of your project

## Concept
- Every jump puts a list entry on top of the stack
- Results in a list of recently visited files
- You can jump to any file in the list, which will place it on top of the stack again
- You can iterate over the stack, which won't trigger a change in the list
- Doesn't replace the jumplist, but compliments it by allowing you to jump directly to a file
- Doesn't track file positions like the jumplist, only files

## Roadmap
- [x] Prev and next file
- [x] Ignore files outside cwd
- [ ] Open buffer in current window
- [ ] Save list to disk per cwd
- [ ] Custom highlight groups
- [ ] Clear list
- [ ] Git support
- [ ] File changed marker
- [ ] Diagnostic marker
- [ ] Pin buffer to specific number
- [ ] Better filetype exclusion
