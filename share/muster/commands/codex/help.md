# desc
Manage a window's persistent Codex session.
# opt help
Display help for `muster codex`.
# man
## DESCRIPTION
`muster codex` associates a standing Codex thread with each named window. The
default thread works from `~/pane/<slug>` and is addressed as `<slug>-codex` by
the message system. Explicit named seats use the address `<slug>-<seat>` while
sharing the same window directory and Wicket endpoint.

Sessions run through one shared Codex app-server. `muster codex create` creates
a named seat, `muster codex tui` opens a thread in the terminal, `muster codex
popup` opens a named seat in a persistent popup, and `muster codex nudge`
submits a turn without attaching a TUI.

The physical window slug and participant address are distinct.
`MUSTER_WINDOW_SLUG` contains the window name; `MUSTER_SLUG` contains the full
participant address.
## OPTIONS
> options
## COMMANDS
> commands
