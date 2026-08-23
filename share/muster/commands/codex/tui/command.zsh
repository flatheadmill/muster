function :help:codex:tui {
    help=$(<${functions_source[:help:codex:tui]:A:h}/help.md)
}

function :args:codex:tui {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:codex:tui {
    [[ -v o_slug ]] || abend 'fatal: slug is a required argument'
    muster_window_slug $o_slug

    typeset pane_dir=~/pane/$o_slug
    [[ -d $pane_dir ]] \
        || abend 'fatal: no window directory at %s; create the window before starting Codex' "$pane_dir"
    builtin cd -- "$pane_dir" \
        || abend 'fatal: unable to enter window directory: %s' "$pane_dir"

    codex_session_file $o_slug
    typeset sid_file=$REPLY
    typeset -a codex_args=( "$@" )
    export MUSTER_WINDOW_SLUG=$o_slug
    export MUSTER_SLUG=${o_slug}-codex

    codex_pane_configure $o_slug

    typeset session_id
    if codex_session_id_read $sid_file; then
        session_id=$REPLY
    else
        codex_session_start $o_slug $sid_file
        codex_session_id_read $sid_file
        session_id=$REPLY
    fi

    codex_daemon_settings $o_slug
    "${zshctl[argzero]:A}" codex nudge --slug $o_slug --probe >/dev/null \
        || abend 'fatal: unable to configure daemon-backed Codex session'

    exec codex resume --remote "unix://$codex_daemon_socket" \
        "${(@)codex_daemon_cli_args}" "${(@)codex_args}" "$session_id"
}
