# desc
Execute Lua in a running Neovim instance.
# opt help
Display help for `muster nvim lua`.
# opt slug -- address
Resolve the workspace socket; hyphens denote nested directories.
# man
## DESCRIPTION
`muster nvim lua` executes one Lua chunk through Neovim's RPC interface. The
chunk may be the sole argument or standard input. A non-nil return value is
printed as JSON. Without `--slug`, the command uses `NVIM\_SOCKET`.

Multiline chunks may be supplied through a heredoc.

```
muster nvim lua --slug widget 'return vim.version()'
```
## OPTIONS
> options
