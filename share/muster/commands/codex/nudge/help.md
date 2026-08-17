# desc
Submit one turn to a standing Codex session.
# opt help
Display help for `muster codex nudge`.
# opt slug -- name
The window slug to nudge. Required.
# opt probe
Configure and resume the thread without starting a turn.
# man
## DESCRIPTION
`muster codex nudge` starts the shared Codex app-server when needed, resumes the
selected thread with its window configuration, submits the prompt read from
standard input, and exits after the app-server accepts the turn.

Message delivery uses this command for addresses ending in `-codex`. `--probe`
loads the thread without submitting a prompt.
## OPTIONS
> options
