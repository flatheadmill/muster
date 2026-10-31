# desc
Send keys to a running Neovim instance.
# opt help
Display help for `muster nvim send`.
# opt slug -- address
Resolve the workspace socket; hyphens denote nested directories.
# man
## DESCRIPTION
`muster nvim send` passes one keys argument to Neovim's `--remote-send`.
Without `--slug`, it uses `NVIM\_SOCKET`.

```
muster nvim send --slug widget '<Esc>:checktime<CR>'
```
## OPTIONS
> options
