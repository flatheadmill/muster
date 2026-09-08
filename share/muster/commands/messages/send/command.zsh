function :help:messages:send {
    help=$(<${functions_source[:help:messages:send]:A:h}/help.md)
}

function :args:messages:send {
    eval "$(args -bx h,help -s s,slug -s f,from -- "$@")"
}

function :execute:messages:send {
    if [[ ${1:-} == remote ]]; then
        delegate "$@"
        return
    fi

    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    muster_address $o_slug
    typeset window_slug=${o_slug%%-*}
    [[ -d $HOME/pane/$window_slug ]] ||
        abend 'fatal: no window exists for address: %s' "$o_slug"

    typeset from=
    if [[ -v o_from ]]; then
        from=$o_from
    elif [[ -n ${MUSTER_SLUG:-} ]]; then
        from=$MUSTER_SLUG
    elif [[ $PWD == $HOME/pane/* ]]; then
        from=${PWD#$HOME/pane/}
        from=${from//\//-}
    fi
    [[ -z $from ]] || muster_address $from

    typeset message=$(cat)
    typeset payload=$(jq -cn \
        --arg slug "$o_slug" \
        --arg from "$from" \
        --arg message "$message" \
        '{ slug: $slug, from: $from, message: $message }') ||
        abend 'fatal: unable to encode message'

    muster_messages_remote send "$payload"
}
