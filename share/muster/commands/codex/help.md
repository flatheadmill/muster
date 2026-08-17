# desc
Manage a window's persistent Codex session.
# opt help
Display help for `muster codex`.
# man
## DESCRIPTION
`muster codex` associates one standing Codex thread with each named window. The
thread works from `~/pane/<slug>` and is addressed as `<slug>-codex` by the
message system.

Sessions run through one shared Codex app-server. `muster codex tui` opens or
resumes a thread in the terminal. `muster codex nudge` submits a turn without
attaching a TUI, allowing an arriving message to wake a session that is not on
screen.

The physical window slug and participant address are distinct.
`MUSTER_WINDOW_SLUG` contains the window name; `MUSTER_SLUG` contains the
`<slug>-codex` address.
## OPTIONS
> options
## COMMANDS
> commands
