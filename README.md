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

### Changing Reasoning Effort

Codex 0.154.0 includes an experimental option for changing reasoning effort within a conversation while preserving the cached prompt prefix. To enable it, add this key to the existing `[features]` section in `~/.codex/config.toml` (or create the section if it is absent):

```toml
[features]
reasoning_effort_override = true
```

The option requires an OpenAI model using Responses Lite, including `gpt-6-astra` and `gpt-5.6-sol`. Codex records effort changes in conversation history while keeping request-level effort stable. This avoids invalidating the cached prefix solely because effort changed; it does not guarantee a cache hit. Switching models still uses a different model-specific cache.

After changing the setting, close the Codex TUIs, restart Muster's shared Codex app-server when its turns have finished, and reopen the TUIs. Then select the desired effort in the TUI. Verify that `codex features list` reports `reasoning_effort_override` as `true`; a running app-server must restart to pick up the configuration change.

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
