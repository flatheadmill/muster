# desc
Create a persistent Grok Build session.
# opt help
Display help for `muster grok create`.
# opt slug -- name
Set the window slug. Required.
# man
## DESCRIPTION
`muster grok create` reserves a Grok Build session ID for a named window without
starting Grok. The participant address is `<slug>-grok`, and the session works
from `~/pane/<slug>`.

Creation is explicit. `muster grok run` opens the session after it exists.
## OPTIONS
> options
