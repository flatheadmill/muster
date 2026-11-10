# desc
Convert one flat OMP room into its audit seat.
# opt help
Display help for `muster omp migrate`.
# opt slug
Set the window slug to convert.
# opt recover
Resume an unfinished cold conversion from the paths actually present.
# man
## DESCRIPTION
Converts one room without launching OMP or tmux sessions. Stop the legacy,
audit, and bench processes, their listeners, and any other writers first. Use
the upgraded Muster for all access to the room. Session checks cannot prove
that an independently started process is gone. The transaction directory is
an interruption marker, not protection against concurrent writers or older
executables.

```console
muster omp migrate --slug widget
muster omp migrate --slug widget --recover
```

The whole flat `omp/<slug>` directory is renamed into
`omp/<slug>/audit`, preserving the transcript, its `sid/` artifacts, hidden
files, locks, and unknown companions. The whole `messages/<slug>-omp` mailbox
moves to `messages/<slug>-audit`, including inbox, outbox, `.read`, and `.waited`.
Moves require the same filesystem and never merge with an existing destination.
A room may have only a transcript, only a mailbox, both, or neither. An empty
audit directory still establishes the seat and retires the old address.

Prepare `~/pane/<slug>/.omp/audit/config.json` before conversion, preserving
the intended audit model roles, thinking effort, advisor policy and automatic
model-switching behavior. The declaration follows the format documented by
`muster omp run --help`. Preparation is a separate deliberate operation.
Migration only validates that JSON file; it never invokes OMP, discovers
configuration or selects substitute policy. A missing or invalid declaration
refuses before any mutation. The native `.omp/config.yml` and its companions
remain untouched, even if the YAML is malformed. The bench declaration is
prepared separately before its first launch.

Read-only preflight checks paths, declarations, mailboxes, participant
collisions and private sessions. After provisioning the state namespace if
necessary, the first room mutation creates `omp/.<slug>.migrating/` with
`mkdir`. The old room is staged inside it as `legacy/`. Installing that payload
as audit leaves the transaction directory present until configuration, state
and mail all validate. Removing the empty marker is the final mutation.

## RECOVERY
Keep the room quiet and run the same command with `--recover`. An ordinary
invocation refuses an existing marker. Recovery does not overwrite it, trust
a saved phase, or roll completed moves back.

| Observed state | Recovery action |
| --- | --- |
| Flat room remains; no staged payload or audit | Stage the whole room, then install audit. |
| `legacy/` is staged; destination absent or empty | Rename the staged directory into audit. |
| Audit exists; staged payload is absent | Validate audit and its prepared declaration, then finish the mailbox move. |
| Legacy mailbox exists; audit mailbox is absent | Rename the whole mailbox. |
| Legacy mailbox is absent | Retain an already moved audit mailbox, or leave mail absent. |
| Both copies exist, an unexpected entry appears, or a path is a symlink | Refuse and leave all evidence for inspection. |

The marker blocks launch, inventory, rename and access to the room's OMP
mailboxes until completion. Failure leaves it in place. After completion,
ordinary audit or bench directories identify the seated layout; mailbox
operations reject `<slug>-omp` and name `<slug>-audit`, without forwarding.
The seat directories persist even when empty. Renaming the project moves that
identity with its state and mail.

This command supports the current flat layout only. Historical topic trees or
mixed layouts require a separately reviewed procedure. It does not import or
select topics, convert multiple rooms, or support remote message storage.
Already seated rooms with valid declarations and no legacy mailbox are
reported without modification.
## OPTIONS
> options
