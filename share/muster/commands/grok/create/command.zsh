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
    (( ${+commands[uuidgen]} )) || abend 'fatal: uuidgen is not installed'

    grok_state_dir $o_slug
    typeset state_dir=$REPLY parent=${REPLY:h}
    [[ ! -e $state_dir ]] || abend 'fatal: Grok session already exists: %s-grok' "$o_slug"

    mkdir -p $parent
    typeset staged=$(mktemp -d $parent/.${o_slug}.XXXXXX) \
        || abend 'fatal: cannot stage Grok session: %s-grok' "$o_slug"
    {
        typeset session_id=$(uuidgen) \
            || abend 'fatal: cannot generate Grok session ID'
        session_id=${(L)session_id}
        print -r -- $session_id > $staged/sid \
            || abend 'fatal: cannot record Grok session ID'
        chmod 600 $staged/sid
        mv $staged $state_dir \
            || abend 'fatal: cannot install Grok session: %s-grok' "$o_slug"
        staged=

        jq -cn \
            --arg address "${o_slug}-grok" \
            --arg sessionId "$session_id" \
            '{address: $address, sessionId: $sessionId}'
    } always {
        [[ -z $staged ]] || rm -rf $staged
    }
}
