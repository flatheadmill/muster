# desc
Wait until an inbox has something new to read.
# opt help
Display help for `muster messages listen`.
# opt slug -- address
The recipient address. Required.
# man
## DESCRIPTION
`muster messages listen` blocks until a message arrives, then prints an
instruction to read the inbox and exits. It is suited to harnesses that start a
fresh background listener after handling each batch.

```
muster messages listen --slug widget-omp
```
## OPTIONS
> options
