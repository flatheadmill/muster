function :help:codex:nudge {
    help=$(<${functions_source[:help:codex:nudge]:A:h}/help.md)
}

function :args:codex:nudge {
    eval "$(args -bx h,help p,probe -s s,slug -- "$@")"
}

function :execute:codex:nudge {
    [[ -v o_slug ]] || abend 'fatal: slug is a required argument'
    muster_window_slug $o_slug

    codex_session_file $o_slug
    typeset sid_file=$REPLY
    codex_session_id_read $sid_file \
        || abend 'fatal: no codex session for slug %s' "$o_slug"
    typeset session_id=$REPLY

    codex_daemon_settings $o_slug
    codex_app_server_ensure $codex_daemon_socket

    typeset -a args=(
        --socket "$codex_daemon_socket"
        --thread "$session_id"
        --resume-config "$codex_daemon_resume_config"
    )
    (( o_probe )) && args+=( --probe )

    "$(codex_nudge_bin)" "${(@)args}"
}
