function :args:messages:peek:remote {
    eval "$(args -- "$@")"
}

function :execute:messages:peek:remote {
    typeset json=$(cat)
    typeset slug=$(jq -er '.slug | strings | select(length > 0)' <<< "$json") ||
        abend 'fatal: slug is required'
    muster_address $slug

    muster_messages_dir $slug
    typeset msgdir=$REPLY
    typeset inbox=$msgdir/.inbox
    typeset read_file=$msgdir/.read

    typeset last_read=
    [[ ! -f $read_file ]] || last_read=$(<$read_file)

    typeset file
    for file in $inbox/*(N.on); do
        [[ -z $last_read || ${file:t} > $last_read ]] || continue
        jq -cn '{ status: "ok" }'
        return
    done

    jq -cn '{ status: "empty" }'
}
