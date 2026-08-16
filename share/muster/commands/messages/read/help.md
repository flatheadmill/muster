# desc
Read every unread message for a participant.
# opt help
Display help for `muster messages read`.
# opt slug -- address
The recipient address. Required.
# man
## DESCRIPTION
`muster messages read` prints every message newer than the recipient's read
cursor, then advances the cursor to the final message in the batch.

```
muster messages read --slug widget-codex
```
## OPTIONS
> options
