# desc
Open a named Codex seat in a popup.
# opt help
Display help for `muster codex popup`.
# opt slug
Set the window slug.
# opt seat
Set the named Codex seat.
# man
## DESCRIPTION
`muster codex popup` opens an existing named seat in a full-screen tmux popup.
The seat runs in a persistent private tmux session, so closing and reopening the
popup returns to the same Codex TUI and thread.

The conventional `sol` and `astra` seats are created automatically with `xhigh`
reasoning effort when they do not exist. They use `gpt-5.6-sol` and
`gpt-6-astra`, respectively. Other named seats remain explicit.
## OPTIONS
> options
