# desc
Print a nudge whenever an inbox should be read.
# opt help
Display help for `muster messages monitor`.
# opt slug -- address
The recipient address. Required.
# man
## DESCRIPTION
`muster messages monitor` prints one instruction when it starts and another
whenever a message arrives. It is a persistent, blocking stream intended for a
participant harness that can react to each line of output.

The monitor is stateless. `muster messages read` owns the read cursor and drains
the unread batch after a nudge.

```
muster messages monitor --slug widget-fable
```
## OPTIONS
> options
