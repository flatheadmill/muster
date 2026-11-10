zmodload zsh/datetime

function :args:messages:send:remote {
    eval "$(args -- "$@")"
}

function :execute:messages:send:remote {
    typeset json=$(cat)
    typeset slug=$(jq -er '.slug | strings | select(length > 0)' <<< "$json") ||
        abend 'fatal: slug is required'
    typeset from=$(jq -r '.from // ""' <<< "$json") ||
        abend 'fatal: invalid sender'
    typeset message=$(jq -er '.message | strings' <<< "$json") ||
        abend 'fatal: message is required'

    muster_address $slug
    [[ -z $from ]] || muster_address $from

    muster_messages_dir $slug
    typeset inbox=$REPLY/.inbox
    typeset outbox=
    if [[ -n $from ]]; then
        muster_messages_dir $from
        outbox=$REPLY/.outbox
    fi
    # Validate both endpoints before publishing, including a retired sender.
    # Prepare the outbox first so an unusable sender cannot cause a delivery
    # followed by a predictable outbox-creation failure.
    [[ -z $outbox ]] || mkdir -p $outbox ||
        abend 'fatal: unable to create outbox: %s' "$outbox"
    [[ -z $outbox || -w $outbox ]] ||
        abend 'fatal: outbox is not writable: %s' "$outbox"
    mkdir -p $inbox || abend 'fatal: unable to create inbox: %s' "$inbox"

    typeset seconds=${EPOCHREALTIME%.*}
    typeset fraction=${EPOCHREALTIME#*.}
    typeset filename=$(strftime '%Y-%m-%dT%H-%M-%S' $seconds).${fraction[1,6]}.$$
    typeset staged=$(mktemp "$inbox/.incoming.XXXXXX") ||
        abend 'fatal: unable to stage message'

    {
        printf '%s\n' "$message" > $staged ||
            abend 'fatal: unable to write message'
        mv $staged $inbox/$filename ||
            abend 'fatal: unable to deliver message'
        staged=

        if [[ -n $from ]]; then
            cp $inbox/$filename $outbox/$filename ||
                abend 'fatal: unable to record sent message'
        fi
    } always {
        [[ -z $staged ]] || rm -f $staged
    }

    if [[ $slug != putter ]] && muster_codex_address_resolve $slug; then
        typeset window_slug=$muster_codex_address_window
        typeset seat=$muster_codex_address_seat
        typeset nudge="You have messages: \`muster messages read --slug $slug\`."
        typeset -a nudge_args=( --slug $window_slug )
        [[ -z $seat ]] || nudge_args+=( --seat $seat )
        if ! print -r -- "$nudge" |
            "${zshctl[argzero]:A}" codex nudge "${(@)nudge_args}"
        then
            print -u2 -- "warning: message delivered, but Codex could not be nudged: $slug"
        fi
    fi

    jq -cn --arg file "$filename" '{ status: "ok", file: $file }'
}
