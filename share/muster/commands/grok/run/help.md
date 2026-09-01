# desc
Open a persistent Grok Build session.
# opt help
Display help for `muster grok run`.
# opt slug -- name
Set the window slug. Required.
# man
## DESCRIPTION
`muster grok run` opens a Grok Build session in a full-screen tmux popup. When
the window has no Grok session, Muster reserves its session ID automatically.
Later process launches resume the same Grok conversation.

Muster marks `~/pane/<slug>` as trusted when Grok starts. Grok otherwise uses
its existing model, reasoning, and permission configuration.

The private tmux session remains alive while the popup is detached. Grok runs
with `MUSTER_WINDOW_SLUG=<slug>` and `MUSTER_SLUG=<slug>-grok` so it can
participate in the message system.
## OPTIONS
> options
