function :help:ssh {
    help=$(<${functions_source[:help:ssh]:A:h}/help.md)
}

function :args:ssh {
    typeset parsed
    parsed=$(args -UC -bx h,help -- "$@") || return
    eval "$parsed"
}

function :execute:ssh {
    delegate "$@"
}
