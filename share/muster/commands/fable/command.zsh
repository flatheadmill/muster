function :help:fable {
    help=$(<${functions_source[:help:fable]:A:h}/help.md)
}

function :args:fable {
    eval "$(args -CU -bx h,help -- "$@")"
}

function :execute:fable {
    delegate "$@"
}
