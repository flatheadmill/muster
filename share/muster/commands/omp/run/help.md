# desc
Run the window's OMP session.
# opt help
Display help for `muster omp run`.
# opt slug
Set the window slug.
# man
## DESCRIPTION
Starts or resumes the window's one OMP session and opens it in a popup. The
effective project configuration supplies the primary model. Muster passes that
model explicitly when resuming so an older model persisted in the transcript
does not override the current project default.

The session transcript is stored at
`~/.local/state/muster/omp/<slug>/sid.jsonl`. OMP receives the participant
address `<slug>-omp` and current Muster messaging instructions.
## OPTIONS
> options
