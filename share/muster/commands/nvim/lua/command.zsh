function :help:nvim:lua {
    help=$(<${functions_source[:help:nvim:lua]:A:h}/help.md)
}

function :args:nvim:lua {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:nvim:lua {
    (( $# <= 1 )) || abend 'fatal: at most one Lua chunk is allowed'
    muster_nvim_socket ${o_slug:-}
    typeset socket=$REPLY chunk
    if (( $# )); then
        chunk=$1
    else
        chunk=$(cat)
    fi
    [[ -n ${chunk//[[:space:]]/} ]] || abend 'fatal: a Lua chunk is required'

    typeset stage
    stage=$(mktemp "${TMPDIR:-/tmp}/muster.nvim.XXXXXX") ||
        abend 'fatal: unable to stage Lua chunk'
    {
        print -rn -- "$chunk" > $stage ||
            abend 'fatal: unable to write staged Lua chunk'
        typeset stage_expression result
        stage_expression=$(jq -Rn --arg path "$stage" '$path') ||
            abend 'fatal: unable to encode staged Lua path'
        result=$(muster_nvim_remote --server "$socket" --remote-expr \
            "luaeval(\"(function() local value = assert(loadfile(_A))(); if value == nil then return string.char() end; return vim.json.encode(value) end)()\", $stage_expression)") || return
        [[ -z $result ]] || print -r -- "$result"
    } always {
        rm -f -- $stage
    }
}
