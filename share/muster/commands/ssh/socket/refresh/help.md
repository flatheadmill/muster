# desc
Refresh the stable SSH\_AUTH\_SOCK now.
# opt help
Display help for `muster ssh socket refresh`.
# opt quiet
Do not print the resulting link.
# man
## DESCRIPTION
Reads the current SSH\_AUTH\_SOCK from the macOS launchd environment and
atomically points `~/.ssh/agent/local` at it.
## OPTIONS
> options
