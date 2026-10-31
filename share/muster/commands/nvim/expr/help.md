# desc
Evaluate an expression in a running Neovim instance.
# opt help
Display help for `muster nvim expr`.
# opt slug -- address
Resolve the workspace socket; hyphens denote nested directories.
# man
## DESCRIPTION
`muster nvim expr` passes one expression to Neovim's `--remote-expr` and
prints its result. Without `--slug`, it uses `NVIM\_SOCKET`.

```
muster nvim expr --slug widget 'json_encode(nvim_list_wins())'
```
## OPTIONS
> options
