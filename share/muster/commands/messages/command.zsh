function :help:messages {
    help=$(<${functions_source[:help:messages]:A:h}/help.md)
}

function :args:messages {
    eval "$(args -CU -bx h,help -- "$@")"
}

function :execute:messages {
    delegate "$@"
}
