function :help:nvim:send {
    help=$(<${functions_source[:help:nvim:send]:A:h}/help.md)
}

function :args:nvim:send {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:nvim:send {
    (( $# == 1 )) || abend 'fatal: one keys argument is required'
    muster_nvim_socket ${o_slug:-}
    muster_nvim_remote --server "$REPLY" --remote-send "$1"
}
