function :help:messages:peek {
    help=$(<${functions_source[:help:messages:peek]:A:h}/help.md)
}

function :args:messages:peek {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:messages:peek {
    if [[ ${1:-} == remote ]]; then
        delegate "$@"
        return
    fi

    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    muster_address $o_slug
    typeset payload=$(jq -cn --arg slug "$o_slug" '{ slug: $slug }')

    typeset response=$(muster_messages_remote peek "$payload") || return $?
    typeset result_status=$(jq -er '.status | strings' <<< "$response" 2>/dev/null) || {
        print -u2 'fatal: message host returned no valid status'
        return 2
    }

    case $result_status in
        (ok) return 0 ;;
        (empty) return 1 ;;
        (*)
            print -u2 "fatal: message host returned unexpected status: $result_status"
            return 2
            ;;
    esac
}
