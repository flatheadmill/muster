function :help:omp {
    help=$(<${functions_source[:help:omp]:A:h}/help.md)
}

function :args:omp {
    eval "$(args -CU -bx h,help -- "$@")"
}

function :execute:omp {
    delegate "$@"
}
