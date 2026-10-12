function :help:ssh:socket:refresh {
    help=$(<${functions_source[:help:ssh:socket:refresh]:A:h}/help.md)
}

function :args:ssh:socket:refresh {
    eval "$(args -bx h,help q,quiet -- "$@")"
}

function :execute:ssh:socket:refresh {
    (( $# == 0 )) || abend 'fatal: refresh takes no arguments'
    muster_ssh_socket_refresh
}
