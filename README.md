# muster

`muster` coordinates participants in durable, named workspaces.

A window can be renamed after its participant clients and Puzzle have stopped. The rename preserves conversation IDs while moving the room, harness state, message history, and cwd-indexed session data together.

```console
$ muster rename --slug widget --to sprocket
```

The first utility is a file-backed message system. Each participant has an address, an inbox, an outbox, and a read cursor. Participants can send and read batches directly, wait for one message, run a one-shot listener, or keep a streaming monitor open for the life of a session.

```console
$ printf '%s\n' 'Please review the change.' | muster messages send --slug widget-fable --from widget
{"status":"ok","file":"2026-08-15T09-41-12.123456.1234"}

$ muster messages read --slug widget-fable
--- message 2026-08-15T09-41-12.123456.1234 ---
Please review the change.
```

Run `muster messages --help` for storage and remote-host configuration.

## Codex

Muster keeps one standing Codex thread for each window. The interactive TUI and message-triggered turns use the same shared app-server configuration, so a conversation continues whether or not its terminal is open.

Opening a new window creates its room at `~/pane/<slug>`. Room slugs use lowercase letters, digits, and underscores; hyphens separate a room from a named participant.

```console
$ muster codex tui --slug widget_502
```

Messages sent to `widget` wake that standing thread after delivery. `muster codex nudge` provides the same mechanism directly.

```console
$ printf '%s\n' 'Review the current work.' | muster codex nudge --slug widget
```

A window may also have an explicitly created named Codex seat. The seat has its
own durable thread and Muster address while sharing the window directory and
Wicket endpoint.

```console
$ muster codex create --slug widget --seat sol --effort high
$ muster codex popup --slug widget --seat sol
$ printf '%s\n' 'Implement the agreed change.' | muster messages send --slug widget-sol --from widget
```

Opening the conventional `sol` or `astra` seat creates it automatically with
`xhigh` reasoning effort when needed:

```console
$ muster codex popup --slug widget --seat sol
$ muster codex popup --slug widget --seat astra
```

## Collaboration

A persistent collaboration popup opens the standing Codex thread in a private
tmux session rooted in the same window directory. The session can be split as
needed. Closing the popup detaches it; opening it again returns to the running
session.

```console
$ muster collaboration --slug widget
```

## Claude Code

Claude and Fable run as persistent participants in private tmux popups. Muster
creates their session IDs automatically, initializes each conversation with
`Ping.`, and resumes it after a process restart.

```console
$ muster claude run --slug widget
$ muster fable run --slug widget
```

Their Muster addresses are `widget-claude` and `widget-fable`.

## Participant defaults

Set personal defaults in `~/.config/muster/participants.zsh` (or under
`$XDG_CONFIG_HOME`). Muster sources this file when it resolves a participant.
These variables can also be exported from the launching shell. To allow shell
overrides, use default assignments in the file:

```zsh
typeset -gx MUSTER_CODEX_MODEL=${MUSTER_CODEX_MODEL:-gpt-6-astra}
typeset -gx MUSTER_CODEX_EFFORT=${MUSTER_CODEX_EFFORT:-max}
typeset -gx MUSTER_CODEX_SERVICE_TIER=${MUSTER_CODEX_SERVICE_TIER:-fast}
typeset -gx MUSTER_ASTRA_EFFORT=${MUSTER_ASTRA_EFFORT:-max}
typeset -gx MUSTER_FABLE_EFFORT=${MUSTER_FABLE_EFFORT:-xhigh}
```

The defaults without configuration remain:

| Participant | Model variable and default | Effort variable and default |
| --- | --- | --- |
| Main Codex | `MUSTER_CODEX_MODEL`: `gpt-5.6-sol` | `MUSTER_CODEX_EFFORT`: inherit Codex configuration |
| Sol popup | `MUSTER_SOL_MODEL`: `gpt-5.6-sol` | `MUSTER_SOL_EFFORT`: `xhigh` |
| Astra popup | `MUSTER_ASTRA_MODEL`: `gpt-6-astra` | `MUSTER_ASTRA_EFFORT`: `xhigh` |
| Claude popup | `MUSTER_CLAUDE_MODEL`: `opus[1m]` | `MUSTER_CLAUDE_EFFORT`: `medium` |
| Fable popup | `MUSTER_FABLE_MODEL`: `claude-fable-5-1[1m]` | `MUSTER_FABLE_EFFORT`: `high` |

Effort accepts `low`, `medium`, `high`, `xhigh`, or `max`, subject to the model's
support. `MUSTER_CODEX_SERVICE_TIER` applies to all Codex participants; when
unset, Codex's own tier configuration applies. Set it to `fast` for Fast mode.
This does not change the user's global Codex configuration.

Named Codex seats retain the model and effort saved when created. New defaults
apply to future seats; explicit `codex create --model` and `--effort` take
precedence. Main Codex settings apply on launch and message-triggered turns.
Claude/Fable defaults apply when their process starts, so detach and reopen
returns to the current process without changing its model or effort.

## Grok Build

Muster records one Grok Build session ID for each window. The first run creates
that conversation automatically, and later process launches resume it in a
persistent tmux popup. `muster grok create --slug widget` can reserve the ID
without starting Grok when needed.

```console
$ muster grok create --slug widget
$ muster grok run --slug widget
```

The participant address is `widget-grok`. Grok can keep a message monitor open
for that address when it should participate in the workspace conversation.

```console
$ muster messages monitor --slug widget-grok
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
