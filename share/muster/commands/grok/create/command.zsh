function :help:grok:create {
    help=$(<${functions_source[:help:grok:create]:A:h}/help.md)
}

function :args:grok:create {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:grok:create {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    [[ $# -eq 0 ]] || abend 'fatal: usage: muster grok create --slug <slug>'
    muster_window_slug $o_slug

    typeset pane_dir=~/pane/$o_slug
    [[ -d $pane_dir ]] \
        || abend 'fatal: no window directory at %s; create the window before creating a Grok session' "$pane_dir"
    grok_session_create $o_slug
    typeset session_id=$REPLY
    jq -cn \
        --arg address "${o_slug}-grok" \
        --arg sessionId "$session_id" \
        '{address: $address, sessionId: $sessionId}'
}
