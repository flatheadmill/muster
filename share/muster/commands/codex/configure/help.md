# desc
Set or clear a window's main Codex model preference.
# opt help
Display help for `muster codex configure`.
# opt slug -- name
The window whose main participant to configure. Required.
# opt model -- model
The Codex model to use. Requires `--effort`.
# opt effort -- effort
Reasoning effort: `low`, `medium`, `high`, or `xhigh`. Requires `--model`.
# opt clear
Remove the preference and restore the ordinary main participant defaults.
Cannot be combined with `--model` or `--effort`.
# man
## DESCRIPTION
`muster codex configure --slug <slug> --model <model> --effort <effort>` saves
the main participant's model and effort without starting a daemon or TUI.
Use `muster codex configure --slug <slug> --clear` to remove the preference.

The preference is stored in `codex/<slug>/config.json` under Muster's state
root, beside `sid.json`. It can be set before the thread exists. It does not
register a participant or change its conversation ID, and follows the window
when renamed. Without the file, the main participant uses `gpt-5.6-sol` with
`medium` effort. An invalid configuration causes an error.

Changes apply on the next Muster resume or nudge. An already attached TUI is
not changed immediately; reopen it to apply the preference. Interactive
`/model` choices are temporary until Muster next applies the saved preference.
Named seats retain their own recorded settings.
## OPTIONS
> options
