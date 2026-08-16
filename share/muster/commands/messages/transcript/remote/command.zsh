function :args:messages:transcript:remote {
    eval "$(args -- "$@")"
}

function :execute:messages:transcript:remote {
    typeset json=$(cat)
    typeset slug=$(jq -er '.slug | strings | select(length > 0)' <<< "$json") ||
        abend 'fatal: slug is required'
    muster_address $slug

    muster_messages_dir $slug
    typeset msgdir=$REPLY
    typeset -a files=(
        $msgdir/.inbox/*(N.on)
        $msgdir/.outbox/*(N.on)
    )
    files=( ${(o)files} )

    typeset file
    integer first=1
    for file in "${(@)files}"; do
        if (( first )); then
            first=0
        else
            printf '\n---\n\n'
        fi
        cat $file
    done
}
