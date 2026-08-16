function :args:messages:monitor:remote {
    eval "$(args -- "$@")"
}

function :execute:messages:monitor:remote {
    muster_require_fswatch

    typeset json=$(cat)
    typeset slug=$(jq -er '.slug | strings | select(length > 0)' <<< "$json") ||
        abend 'fatal: slug is required'
    muster_address $slug

    muster_messages_dir $slug
    typeset inbox=$REPLY/.inbox
    mkdir -p $inbox || abend 'fatal: unable to create inbox: %s' "$inbox"

    typeset nudge="Please check your messages by running \`muster messages read --slug $slug\`."
    print -r -- $nudge

    while true; do
        fswatch -o $inbox | while read -r _; do
            print -r -- $nudge
        done
        print -r -- $nudge
        sleep 1
    done
}
