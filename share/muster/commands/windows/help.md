# desc
List persisted participant registrations as JSON.
# opt json
Emit the participant inventory as JSON. This option is required.
# opt help
Display help for `muster windows`.
# man
## DESCRIPTION
`muster windows --json` prints one JSON array describing participants registered
in Muster's persisted state. Each row contains the primary window, participant
address, and harness. Codex rows also contain the persisted thread ID.

The inventory includes detached participants. It describes durable
registrations and makes no claim that a client, popup, or process is currently
running.
## OPTIONS
> options
