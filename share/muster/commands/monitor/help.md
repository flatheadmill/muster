# desc
Submit a foreground producer's stdout records as Codex nudges.
# opt help
Display help for `muster monitor`.
# opt slug -- window
The existing primary Codex window. Required.
# man
## SYNOPSIS
```synopsis
--slug <window> -- command argument ...
```
## DESCRIPTION
Run one cooperative producer, preserving its argument boundaries. Its stdin is
connected to `/dev/null`; stderr stays local. Each nonblank LF-terminated stdout
record is echoed and submitted to `muster codex nudge`. Spaces and backslashes
are preserved; CR is content, not a second delimiter. Whitespace-only records
are ignored.
Any nonempty unterminated fragment at EOF is a protocol error, never a nudge.

Submissions are serial: each nudge invocation finishes before the next record
is read. Acceptance does not mean turn completion or a distinct turn per record.
Nudge stdout is suppressed; diagnostics remain on stderr. A failed nudge stops
the producer without retry. Delivery is uncertain: a request may remain queued.

After complete output is handled, return the producer's exit status. Protocol
or nudge failure takes precedence. INT, TERM, and HUP are forwarded to the direct
producer, which is waited for and reaped; interruption returns 128 plus the
signal number. An in-flight nudge is also waited for before exit.

The producer must terminate cooperatively, must not daemonize, and must clean
up its own descendants. There are no process groups, forced-kill deadlines,
restarts, retries, persistence, or coalescing. Producers own durable source state
and must flush stdout and keep records reasonably sized; one record is held in
memory. This command is not durable transport.

```
muster monitor --slug widget -- zsh -c 'print first; print diagnostic >&2; print second'
```
## OPTIONS
> options
