# desc
Exchange messages between named participants.
# opt help
Display help for `muster messages`.
# man
## DESCRIPTION
`muster messages` provides file-backed inboxes for participants identified by
addresses such as `widget` or `widget-fable`. Messages are durable and
remain unread until the recipient runs `muster messages read`.

Delivery to the default `<slug>` address or a registered named Codex seat
also nudges the corresponding standing thread. A failed nudge does not roll
back delivery; the message remains unread in the recipient's inbox.

By default, inboxes live under `$XDG_STATE_HOME/muster/messages`, or under
`~/.local/state/muster/messages` when `XDG_STATE_HOME` is unset. Set
`MUSTER_STATE_HOME` to replace the `muster` state directory.

For a remote message host, create `$XDG_CONFIG_HOME/muster/messages.zsh`, or
`~/.config/muster/messages.zsh` when `XDG_CONFIG_HOME` is unset:

```
MUSTER_MESSAGES_SSH=host
```

The remote host must provide `muster` on its non-interactive `PATH`. Set
`MUSTER_MESSAGES_REMOTE_COMMAND` in the same file when another invocation is
required.

OMP audit and bench seats use local message storage alongside their OMP state.
An unfinished OMP conversion blocks its `-omp`, `-audit`, and `-bench` mailbox
addresses. Once audit or bench state exists, the old `-omp` address is retired;
commands refuse it and name `-audit` without forwarding. Send checks both the
sender and recipient before publishing, so a retired sender cannot deliver a
message and only then fail to record its outbox.

Existing named Codex audit or bench participants retain mailbox access before
OMP claims a seated layout. They block OMP launch and migration until their
address ownership is deliberately resolved; reserving names for new OMP seats
does not transfer an existing participant's mail.
## OPTIONS
> options
## COMMANDS
> commands
