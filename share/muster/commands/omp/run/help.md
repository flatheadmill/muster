# desc
Run an OMP audit or bench seat.
# opt help
Display help for `muster omp run`.
# opt slug
Set the window slug.
# opt seat
Select audit or bench. The default is audit.
# man
## DESCRIPTION
Starts or resumes one durable seat in the private `muster-omp` tmux server.
The private session and message address are `<slug>-audit` or `<slug>-bench`.
Closing the popup detaches it; it does not stop the process.

The transcript is `omp/<slug>/<seat>/sid.jsonl` beneath Muster's state root.
The sibling `sid/` tree belongs to that transcript. Seats share the window's
working directory; separate conversations do not provide separate worktrees.

Before launch, prepare `~/pane/<slug>/.omp/<seat>/config.json` as one JSON
object. It must declare `modelRoles.default`, a thinking effort (a model suffix
such as `:high`, or `defaultThinkingLevel`), and a Boolean `advisor.enabled`.
An enabled advisor also requires `modelRoles.advisor`. Supported efforts are
`off`, `minimal`, `low`, `medium`, `high`, `xhigh`, and `auto`.

```json
{
  "modelRoles": {"default": "provider/model:high"},
  "advisor": {"enabled": false}
}
```

Use a model available to the local OMP installation. Pin any other roles or
automatic switching behavior the seat relies on. Muster passes the declaration
as the final explicit `--config` overlay and passes the primary model and effort
explicitly, including on resume. Unspecified settings are inherited.

OMP's native `.omp/config.yml` and `.omp/ssh.json` remain shared. The OMP
settings UI may change that shared base; it does not edit the seat declaration.
Stop and relaunch the seat after editing its declaration. Attaching to a live
session does not apply new policy.

Old flat state or a legacy mailbox requires `muster omp migrate --slug <slug>`.
An unfinished conversion requires its explicit `--recover` operation. A live
legacy private session also blocks launch. An existing mailbox without its seat
directory is a collision; inspect it before establishing a new seat.

OMP seats require message storage on the same host and in the same Muster state
namespace. Remote message storage is not supported for these seats.
## OPTIONS
> options
