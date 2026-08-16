function :help:messages:transcript {
    help=$(<${functions_source[:help:messages:transcript]:A:h}/help.md)
}

function :args:messages:transcript {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:messages:transcript {
    if [[ ${1:-} == remote ]]; then
        delegate "$@"
        return
    fi

    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    muster_address $o_slug
    typeset payload=$(jq -cn --arg slug "$o_slug" '{ slug: $slug }')
    muster_messages_remote transcript "$payload"
}
