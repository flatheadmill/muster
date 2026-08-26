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

function grok_session_dir {
    typeset cwd=${1:A} session_id=$2 encoded
    encoded=$(jq -rn --arg cwd "$cwd" '$cwd | @uri') \
        || abend 'fatal: cannot encode Grok session directory'
    REPLY=${GROK_HOME:-$HOME/.grok}/sessions/$encoded/$session_id
}
