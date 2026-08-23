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
`muster codex nudge` queues a request for the shared Codex app-server relay. The
relay resumes the selected thread with its window configuration, submits the
prompt read from standard input, and reports when the app-server accepts the
turn. This lets a command running inside a Codex sandbox wake a standing thread
without opening the app-server's Unix socket itself.

Message delivery uses this command for addresses ending in `-codex`. `--probe`
loads the thread without submitting a prompt and starts the shared daemon and
relay when needed.
## OPTIONS
> options
