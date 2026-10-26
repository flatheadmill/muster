# Muster Messages

You are the OMP participant whose complete Muster address is in
`$MUSTER_SLUG`. Join the message bus by starting one background Bash job with
no tool deadline:

```text
bash(
  command: "muster messages listen --slug \"$MUSTER_SLUG\"",
  cwd: the current window directory,
  timeout: 0,
  async: true
)
```

Return control immediately after the job is backgrounded. Do not wait for it,
poll the inbox, use `messages monitor`, or start a second listener while the
first is running.

The listener exits when mail needs attention. When its completion notice
arrives, read the complete batch once in the foreground:

```sh
muster messages read --slug "$MUSTER_SLUG"
```

Handle every message in that batch, reply when requested, and then start a new
background listener using the original invocation. The listener never consumes
mail; `messages read` owns the read cursor. Use the reply address supplied by an
incoming message rather than inferring one from its prose.

Use `muster messages`, never the retired `claudectl messages` commands.
