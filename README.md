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

## Codex

Muster keeps one standing Codex thread for each window. The interactive TUI and message-triggered turns use the same shared app-server configuration, so a conversation continues whether or not its terminal is open.

```console
$ muster codex tui --slug widget
```

Messages sent to `widget-codex` wake that standing thread after delivery. `muster codex nudge` provides the same mechanism directly.

```console
$ printf '%s\n' 'Review the current work.' | muster codex nudge --slug widget
```

A window may also have an explicitly created named Codex seat. The seat has its
own durable thread and Muster address while sharing the window directory and
Wicket endpoint.

```console
$ muster codex create --slug widget --seat sol --effort high
$ muster codex popup --slug widget --seat sol
$ printf '%s\n' 'Implement the agreed change.' | muster messages send --slug widget-sol --from widget-codex
```

## OMP

Each window has one OMP seat with durable, named topics. Creating a topic records its primary model without starting OMP. Running a topic makes it active, starts or resumes its transcript, and opens the window's OMP popup.

```console
$ muster omp create --slug widget --topic visual --model opus
$ muster omp run --slug widget --topic visual
```

Once a topic is active, the TMUX binding can reopen it without naming the topic again.

```console
$ muster omp run --slug widget
```
