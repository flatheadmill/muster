function :help:messages:read {
    help=$(<${functions_source[:help:messages:read]:A:h}/help.md)
}

function :args:messages:read {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:messages:read {
    if [[ ${1:-} == remote ]]; then
        delegate "$@"
        return
    fi

    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    muster_address $o_slug
    typeset payload=$(jq -cn --arg slug "$o_slug" '{ slug: $slug }')

    typeset response remote_status
    response=$(muster_messages_remote read "$payload")
    remote_status=$?

    typeset result_status
    result_status=$(jq -er '.status | strings' <<< "$response" 2>/dev/null) || {
        print -u2 'fatal: message host returned no valid status'
        return 1
    }

    case $result_status in
        (ok)
            jq -er '.messages[] | "--- message \(.file) ---\n\(.content)"' \
                <<< "$response" || {
                print -u2 'fatal: message host returned an invalid batch'
                return 1
            }
            ;;
        (empty)
            (( remote_status == 0 )) || return $remote_status
            print 'No messages.'
            ;;
        (*)
            print -u2 "fatal: message host returned unexpected status: $result_status"
            return 1
            ;;
    esac
}
