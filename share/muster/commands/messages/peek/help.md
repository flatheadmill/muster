# desc
Check whether a participant has unread messages.
# opt help
Display help for `muster messages peek`.
# opt slug -- address
The recipient address. Required.
# man
## DESCRIPTION
`muster messages peek` silently checks for messages newer than the recipient's
read cursor without reading them or advancing the cursor. It exits zero when
unread messages exist and one when the inbox is empty.

```
if muster messages peek --slug widget; then
    echo 'messages waiting'
fi
```
## OPTIONS
> options
