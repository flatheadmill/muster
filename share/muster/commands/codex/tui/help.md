# desc
Open or resume a window's Codex session.
# opt help
Display help for `muster codex tui`.
# opt slug -- name
The window slug to open or resume. Required.
# opt seat -- name
Open a named seat instead of the window's default Codex participant.
# man
## DESCRIPTION
`muster codex tui` opens the standing Codex thread for a window in the terminal
UI. The default participant creates `~/pane/<slug>` and a thread when the
window has neither. A named seat must first be created explicitly with `muster
codex create`.

The session uses the shared Codex app-server, the window's Wicket MCP endpoint,
and the standard workspace-write configuration. Arguments after `--` are
passed to Codex.
## OPTIONS
> options
