function :help:nvim {
    help=$(<${functions_source[:help:nvim]:A:h}/help.md)
}

function :args:nvim {
    eval "$(args -CU -bx h,help -- "$@")"
}

function :execute:nvim {
    delegate "$@"
}
