function :help:nvim:expr {
    help=$(<${functions_source[:help:nvim:expr]:A:h}/help.md)
}

function :args:nvim:expr {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:nvim:expr {
    (( $# == 1 )) || abend 'fatal: one expression argument is required'
    muster_nvim_socket ${o_slug:-}
    muster_nvim_remote --server "$REPLY" --remote-expr "$1"
}
