function :help:messages:listen {
    help=$(<${functions_source[:help:messages:listen]:A:h}/help.md)
}

function :args:messages:listen {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:messages:listen {
    if [[ ${1:-} == remote ]]; then
        delegate "$@"
        return
    fi

    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    muster_address $o_slug
    typeset payload=$(jq -cn --arg slug "$o_slug" '{ slug: $slug }')
    muster_messages_remote listen "$payload"
}
