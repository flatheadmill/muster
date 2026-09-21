# desc
Rename a window and its participants.
# opt help
Display help for `muster rename`.
# opt slug
Set the existing window slug.
# opt to
Set the new window slug.
# opt dry-run
Validate and print the rename without changing anything.
# man
## SYNOPSIS
```synopsis
--slug <old>
--to <new>
[--dry-run]
[-h | --help]
```

## DESCRIPTION
`muster rename` gives an existing window a new slug without changing its participant conversation IDs. It moves the window directory, Muster state for every harness, all message addresses beginning with the old slug, Wicket state, and the cwd-indexed Claude and Grok session directories. Named Codex seat addresses and owned MCP routes are rewritten for the new slug.

The operation is deliberately cold. Close Puzzle, stop the window's Codex TUI, and stop every private participant popup before renaming. Muster also refuses a rename while an affected Codex thread is active, a nudge is queued, or a Wicket background job may still be active. Idle Codex threads remain untouched; the next TUI open or message nudge resumes them under the new directory and routing configuration. Renaming a tmux session cannot change the environment or working directory already held by its processes.

When Puzzle owns the window, Muster updates its pane tag without renaming the Puzzle host window. Restart Puzzle after the rename so its window list is reloaded from Muster state. Historical messages and transcripts retain their original text.
## OPTIONS
> options
