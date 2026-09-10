# desc
Create a named Codex seat.
# opt help
Display help for `muster codex create`.
# opt slug
Set the window slug.
# opt seat
Set the participant name within the window.
# opt model
Set the Codex model. Defaults to the configured main Codex model.
# opt effort
Set the reasoning effort: `low`, `medium`, `high`, `xhigh`, or `max`.
# man
## DESCRIPTION
`muster codex create` creates one durable named Codex thread without opening a
terminal UI. The participant address is `<slug>-<seat>`, it works from
`~/pane/<slug>`, and it uses the selected model and reasoning effort.

Creation is explicit. `muster codex popup` opens the seat after it exists.
## OPTIONS
> options
