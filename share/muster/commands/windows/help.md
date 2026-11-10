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

OMP audit and bench transcripts produce separate `<slug>-audit` and
`<slug>-bench` rows. Empty seat directories and configuration alone do not
register a conversation. Unconverted flat transcripts remain visible as
`<slug>-omp` until explicit migration; they cannot be launched by the seat-aware
launcher. An unfinished OMP migration or duplicate participant ownership makes
the inventory fail without emitting a partial array.

An existing named Codex audit or bench seat remains listed before OMP claims
those names. New Codex creation reserves the names; seated OMP state refuses
an ownership collision with an existing registration.
## OPTIONS
> options
