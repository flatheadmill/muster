function :help:messages:get {
    help=$(<${functions_source[:help:messages:get]:A:h}/help.md)
}

function :args:messages:get {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:messages:get {
    if [[ ${1:-} == remote ]]; then
        delegate "$@"
        return
    fi

    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    muster_address $o_slug

    muster_messages_dir $o_slug
    typeset local_dir=$REPLY
    typeset read_file=$local_dir/.read
    typeset last=
    [[ ! -f $read_file ]] || last=$(<$read_file)

    typeset payload=$(jq -cn \
        --arg slug "$o_slug" \
        --arg last "$last" \
        '{ slug: $slug, last: $last }')
    typeset response=$(muster_messages_remote get "$payload") || return $?
    typeset result_status=$(jq -er '.status | strings' <<< "$response") ||
        abend 'fatal: message host returned no valid status'

    [[ $result_status == ok ]] || return
    typeset file=$(jq -er '.file | strings' <<< "$response") ||
        abend 'fatal: message host returned no file'
    typeset content=$(jq -er '.content | strings' <<< "$response") ||
        abend 'fatal: message host returned no content'

    mkdir -p $local_dir ||
        abend 'fatal: unable to create local message directory: %s' "$local_dir"
    printf '%s' "$content" > $local_dir/$file ||
        abend 'fatal: unable to save message: %s' "$file"
    muster_write_cursor $read_file $file
    print -r -- $local_dir/$file
}
