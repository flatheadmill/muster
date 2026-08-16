# muster

`muster` coordinates participants in durable, named workspaces.

The first utility is a file-backed message system. Each participant has an address, an inbox, an outbox, and a read cursor. Participants can send and read batches directly, wait for one message, run a one-shot listener, or keep a streaming monitor open for the life of a session.

```console
$ printf '%s\n' 'Please review the change.' | muster messages send --slug widget-fable --from widget-codex
{"status":"ok","file":"2026-08-15T09-41-12.123456.1234"}

$ muster messages read --slug widget-fable
--- message 2026-08-15T09-41-12.123456.1234 ---
Please review the change.
```

Run `muster messages --help` for storage and remote-host configuration.
