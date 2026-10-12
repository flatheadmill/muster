function :help:ssh:socket:install {
    help=$(<${functions_source[:help:ssh:socket:install]:A:h}/help.md)
}

function :args:ssh:socket:install {
    eval "$(args -bx h,help -- "$@")"
}

function :execute:ssh:socket:install {
    (( $# == 0 )) || abend 'fatal: install takes no arguments'
    muster_ssh_socket_install
}
