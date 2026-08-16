function :args:messages:get:remote {
    eval "$(args -- "$@")"
}

function :execute:messages:get:remote {
    muster_require_fswatch
    muster_timeout_command
    typeset timeout_command=$REPLY

    typeset json=$(cat)
    typeset slug=$(jq -er '.slug | strings | select(length > 0)' <<< "$json") ||
        abend 'fatal: slug is required'
    typeset last=$(jq -r '.last // ""' <<< "$json") ||
        abend 'fatal: invalid cursor'
    muster_address $slug

    muster_messages_dir $slug
    typeset inbox=$REPLY/.inbox
    mkdir -p $inbox || abend 'fatal: unable to create inbox: %s' "$inbox"

    typeset file
    for file in $inbox/*(N.on); do
        [[ -z $last || ${file:t} > $last ]] || continue
        jq -cn \
            --arg file "${file:t}" \
            --arg content "$(<$file)" \
            '{ status: "ok", file: $file, content: $content }'
        return
    done

    $timeout_command 540s fswatch -1 $inbox >/dev/null
    if (( $? == 124 )); then
        jq -cn '{ status: "timeout" }'
        return
    fi

    for file in $inbox/*(N.on); do
        [[ -z $last || ${file:t} > $last ]] || continue
        jq -cn \
            --arg file "${file:t}" \
            --arg content "$(<$file)" \
            '{ status: "ok", file: $file, content: $content }'
        return
    done

    jq -cn '{ status: "timeout" }'
}
