# desc
Send a desktop notification.
# opt help
Display help for `muster tap`.
# opt slug
Set the window slug shown in the notification title.
# man
## SYNOPSIS
```synopsis
<message>
--slug <slug>
[-h | --help]
```

## DESCRIPTION
`muster tap` sends a desktop notification with the given message and an audible
signal. The notification title identifies the window that sent it.

Sandboxed agents must run this command outside the sandbox. `terminal-notifier`
needs access to the macOS notification service, and a sandboxed invocation may
abort without sending the notification.

```
muster tap --slug patina 'Review requested.'
```
## OPTIONS
> options
