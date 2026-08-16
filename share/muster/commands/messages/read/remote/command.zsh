function :args:messages:read:remote {
    eval "$(args -- "$@")"
}

function :execute:messages:read:remote {
    typeset json=$(cat)
    typeset slug=$(jq -er '.slug | strings | select(length > 0)' <<< "$json") ||
        abend 'fatal: slug is required'
    muster_address $slug

    muster_messages_dir $slug
    typeset msgdir=$REPLY
    typeset inbox=$msgdir/.inbox
    typeset read_file=$msgdir/.read
    mkdir -p $inbox || abend 'fatal: unable to create inbox: %s' "$inbox"

    typeset last_read=
    [[ ! -f $read_file ]] || last_read=$(<$read_file)

    typeset -a messages
    typeset file content encoded last_file
    for file in $inbox/*(N.on); do
        [[ -z $last_read || ${file:t} > $last_read ]] || continue
        content=$(<$file) || abend 'fatal: unable to read message: %s' "$file"
        encoded=$(jq -cn \
            --arg file "${file:t}" \
            --arg content "$content" \
            '{ file: $file, content: $content }') ||
            abend 'fatal: unable to encode message: %s' "$file"
        messages+=( "$encoded" )
        last_file=${file:t}
    done

    if (( ${#messages} )); then
        printf '%s\n' "${(@)messages}" |
            jq -sc '{ status: "ok", messages: . }' ||
            abend 'fatal: unable to encode message batch'
        muster_write_cursor $read_file $last_file
    else
        jq -cn '{ status: "empty" }'
    fi
}
