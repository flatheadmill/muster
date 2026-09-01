function :help:grok {
    help=$(<${functions_source[:help:grok]:A:h}/help.md)
}

function :args:grok {
    eval "$(args -CU -bx h,help -- "$@")"
}

function :execute:grok {
    delegate "$@"
}

function grok_state_dir {
    muster_state_root
    REPLY=$REPLY/grok/$1
}

function grok_session_id_read {
    typeset file=$1 session_id
    [[ -s $file ]] || return
    session_id=$(<$file)
    jq -en --arg id "$session_id" '
        $id | test("^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$")
    ' >/dev/null || return
    REPLY=$session_id
}

function grok_session_create {
    typeset slug=$1
    (( ${+commands[uuidgen]} )) || abend 'fatal: uuidgen is not installed'

    grok_state_dir $slug
    typeset state_dir=$REPLY parent=${REPLY:h}
    [[ ! -e $state_dir ]] || abend 'fatal: Grok session already exists: %s-grok' "$slug"

    mkdir -p $parent
    typeset staged=$(mktemp -d $parent/.${slug}.XXXXXX) \
        || abend 'fatal: cannot stage Grok session: %s-grok' "$slug"
    {
        typeset session_id=$(uuidgen) \
            || abend 'fatal: cannot generate Grok session ID'
        session_id=${(L)session_id}
        print -r -- $session_id > $staged/sid \
            || abend 'fatal: cannot record Grok session ID'
        chmod 600 $staged/sid
        mv $staged $state_dir \
            || abend 'fatal: cannot install Grok session: %s-grok' "$slug"
        staged=
        REPLY=$session_id
    } always {
        [[ -z $staged ]] || rm -rf $staged
    }
}

function grok_session_dir {
    typeset cwd=${1:A} session_id=$2 encoded
    encoded=$(jq -rn --arg cwd "$cwd" '$cwd | @uri') \
        || abend 'fatal: cannot encode Grok session directory'
    REPLY=${GROK_HOME:-$HOME/.grok}/sessions/$encoded/$session_id
}
