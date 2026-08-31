function :help:fable:run {
    help=$(<${functions_source[:help:fable:run]:A:h}/help.md)
}

function :args:fable:run {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:fable:run {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    [[ $# -eq 0 ]] || abend 'fatal: usage: muster fable run --slug <slug>'
    muster_claude_run fable $o_slug
}
