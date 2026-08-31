function :help:claude {
    help=$(<${functions_source[:help:claude]:A:h}/help.md)
}

function :args:claude {
    eval "$(args -CU -bx h,help -- "$@")"
}

function :execute:claude {
    delegate "$@"
}
