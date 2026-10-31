function :args:messages:listen:remote {
    eval "$(args -- "$@")"
}

function :execute:messages:listen:remote {
    muster_require_fswatch
    muster_timeout_command
    typeset timeout_command=$REPLY

    typeset json=$(cat)
    typeset slug=$(jq -er '.slug | strings | select(length > 0)' <<< "$json") ||
        abend 'fatal: slug is required'
    muster_address $slug

    muster_messages_dir $slug
    typeset msgdir=$REPLY
    typeset inbox=$msgdir/.inbox
    typeset waited_file=$msgdir/.waited
    typeset read_file=$msgdir/.read
    mkdir -p $inbox || abend 'fatal: unable to create inbox: %s' "$inbox"

    typeset nudge="Please check your messages by running \`muster messages read --slug $slug\`."
    typeset waited last_read floor file
    while true; do
        waited=
        last_read=
        [[ ! -f $waited_file ]] || waited=$(<$waited_file)
        [[ ! -f $read_file ]] || last_read=$(<$read_file)

        # A replacement listener is armed before the pending batch is read. It
        # waits through that read instead of emitting the same nudge again.
        if [[ -n $waited && ( -z $last_read || $last_read < $waited ) ]]; then
            $timeout_command 300s fswatch -1 $msgdir $inbox >/dev/null
            (( $? != 124 )) || printf '.'
            continue
        fi

        # Read may be beyond waited because it drains complete batches.
        floor=$waited
        [[ -z $last_read || ( -n $floor && $last_read < $floor ) ]] || floor=$last_read
        for file in $inbox/*(N.on); do
            [[ -z $floor || ${file:t} > $floor ]] || continue
            muster_write_cursor $waited_file ${file:t}
            print -r -- $nudge
            return
        done

        $timeout_command 300s fswatch -1 $msgdir $inbox >/dev/null
        (( $? != 124 )) || printf '.'
    done
}
