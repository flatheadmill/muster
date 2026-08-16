# desc
Wait for and save the next message.
# opt help
Display help for `muster messages get`.
# opt slug -- address
The recipient address. Required.
# man
## DESCRIPTION
`muster messages get` waits for the next unread message, saves it in the local
state directory, advances its cursor, and prints the saved path. A timeout
produces no output.

```
muster messages get --slug widget-worker
```
## OPTIONS
> options
