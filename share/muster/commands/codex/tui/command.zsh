function :help:codex:tui {
    help=$(<${functions_source[:help:codex:tui]:A:h}/help.md)
}

function :args:codex:tui {
    eval "$(args -bx h,help -s s,slug n,seat -- "$@")"
}

function :execute:codex:tui {
    [[ -v o_slug ]] || abend 'fatal: slug is a required argument'
    muster_window_slug $o_slug

    typeset pane_dir=~/pane/$o_slug
    [[ -d $pane_dir ]] \
        || abend 'fatal: no window directory at %s; create the window before starting Codex' "$pane_dir"
    builtin cd -- "$pane_dir" \
        || abend 'fatal: unable to enter window directory: %s' "$pane_dir"

    typeset seat=${o_seat:-}
    typeset address=$o_slug
    typeset model=gpt-5.6-sol
    typeset effort=
    if [[ -n $seat ]]; then
        codex_seat_settings $o_slug $seat
        address=$codex_seat_address
        model=$codex_seat_model
        effort=$codex_seat_effort
    fi

    codex_session_file $o_slug $seat
    typeset sid_file=$REPLY
    typeset -a codex_args=( "$@" )
    export MUSTER_WINDOW_SLUG=$o_slug
    export MUSTER_SLUG=$address

    codex_pane_configure $o_slug

    typeset session_id
    if codex_session_id_read $sid_file; then
        session_id=$REPLY
    elif [[ -n $seat ]]; then
        abend 'fatal: Codex seat has no session: %s' "$address"
    else
        codex_session_start $o_slug $sid_file $address $model $effort
        codex_session_id_read $sid_file
        session_id=$REPLY
    fi

    codex_daemon_settings $o_slug $address $model $effort
    typeset -a nudge_args=( --slug $o_slug --probe )
    [[ -z $seat ]] || nudge_args+=( --seat $seat )
    "${zshctl[argzero]:A}" codex nudge "${(@)nudge_args}" >/dev/null \
        || abend 'fatal: unable to configure daemon-backed Codex session'

    exec codex resume --remote "unix://$codex_daemon_socket" \
        "${(@)codex_daemon_cli_args}" "${(@)codex_args}" "$session_id"
}
