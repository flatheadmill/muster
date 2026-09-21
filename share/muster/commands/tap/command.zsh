function :help:tap {
    help=$(<${functions_source[:help:tap]:A:h}/help.md)
}

function :args:tap {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:tap {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    typeset message=${1:-}
    [[ -n $message ]] || abend 'fatal: message is required'
    (( $# == 1 )) || abend 'fatal: usage: muster tap --slug <slug> <message>'
    (( ${+commands[terminal-notifier]} )) ||
        abend 'fatal: terminal-notifier is not installed'

    terminal-notifier -message "$message" -title "Muster: $o_slug" -sound Funk
}
