function muster_messages_nudge_putter {
    typeset url='codex://threads/01a0bba5-c5a1-7bc3-8219-b2266d5a9b36?prompt=Check%20Muster%20messages%2C%20please.'

    # Putter currently wakes itself with timers. The desktop nudge remains here
    # as an experiment, but opening the app steals focus even with open -g.
    # open -a /Applications/ChatGPT.app "$url" || return
    # sleep 1
    # osascript <<'APPLESCRIPT'
    # tell application "ChatGPT" to activate
    # delay 0.2
    # tell application "System Events" to key code 36
    # APPLESCRIPT
}

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
    [[ $o_slug == putter || -d $HOME/pane/$window_slug ]] ||
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

    muster_messages_remote send "$payload" || return $?

    if [[ $o_slug == putter ]] && ! muster_messages_nudge_putter; then
        print -u2 -- 'warning: message delivered, but Putter could not be nudged'
    fi
}
