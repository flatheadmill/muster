# desc
Send a message to a participant.
# opt help
Display help for `muster messages send`.
# opt slug -- address
The recipient address. Required.
# opt from -- address
The sender address.
# man
## DESCRIPTION
`muster messages send` reads a message from standard input and delivers it to
the inbox named by `--slug`. The address must belong to an existing window
directory under `~/pane`.

The sender comes from `--from`, then `MUSTER_SLUG`, then the current directory
when it is beneath `~/pane`. A known sender receives an outbox copy.

```
printf '%s\n' 'Please review the change.' |
    muster messages send --slug widget-fable --from widget
```
## OPTIONS
> options
