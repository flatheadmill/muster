# desc
Open a persistent Codex workspace.
# opt help
Display help for `muster collaboration`.
# opt slug
Set the window slug.
# man
## DESCRIPTION
`muster collaboration` opens the standing Codex thread in a full-screen tmux
popup rooted at `~/pane/<slug>`. The popup is a tmux session, so it can be split
into additional panes while it is open.

The private tmux session remains alive when the popup closes. Opening the same
window again returns to Codex and any panes added to the session.
## OPTIONS
> options
