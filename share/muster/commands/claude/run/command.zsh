function :help:claude:run {
    help=$(<${functions_source[:help:claude:run]:A:h}/help.md)
}

function :args:claude:run {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:claude:run {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    [[ $# -eq 0 ]] || abend 'fatal: usage: muster claude run --slug <slug>'
    muster_claude_run claude $o_slug
}
