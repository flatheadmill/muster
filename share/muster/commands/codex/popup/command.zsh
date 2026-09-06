function :help:codex:popup {
    help=$(<${functions_source[:help:codex:popup]:A:h}/help.md)
}

function :args:codex:popup {
    eval "$(args -bx h,help -s s,slug n,seat -- "$@")"
}

function :execute:codex:popup {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    [[ -v o_seat ]] || abend 'fatal: --seat is required'
    [[ $# -eq 0 ]] || abend 'fatal: usage: muster codex popup --slug <slug> --seat <seat>'
    [[ -n ${TMUX:-} ]] || abend 'fatal: muster codex popup must run inside tmux'
    muster_window_slug $o_slug
    muster_window_slug $o_seat

    codex_seat_config_file $o_slug $o_seat
    typeset model=
    if [[ ! -e $REPLY ]]; then
        case $o_seat in
        (sol) model=gpt-5.6-sol ;;
        (astra) model=gpt-6-astra ;;
        (*) model= ;;
        esac
    fi
    if [[ -n ${model:-} ]]; then
        "${zshctl[argzero]:A}" codex create \
            --slug $o_slug \
            --seat $o_seat \
            --model $model \
            --effort xhigh \
            >/dev/null
    fi

    codex_seat_settings $o_slug $o_seat
    typeset address=$codex_seat_address
    codex_session_file $o_slug $o_seat
    codex_session_id_read $REPLY \
        || abend 'fatal: Codex seat has no session: %s' "$address"

    typeset dir=~/pane/$o_slug
    [[ -d $dir ]] || abend 'fatal: no window directory at %s' "$dir"

    typeset server=muster-codex popup_command foreground= background=
    typeset client=$(tmux display-message -p '#{client_name}')
    [[ -n $client ]] || abend 'fatal: cannot find the current tmux client'
    if muster_tmux_terminal_color MUSTER_TERMINAL_FOREGROUND; then
        foreground=$REPLY
    fi
    if muster_tmux_terminal_color MUSTER_TERMINAL_BACKGROUND; then
        background=$REPLY
    fi

    if env -u TMUX tmux -L $server has-session -t "=$address" 2>/dev/null; then
        env -u TMUX tmux -L $server set-option -g prefix C-a
        env -u TMUX tmux -L $server unbind-key C-b 2>/dev/null
        env -u TMUX tmux -L $server bind-key C-a send-prefix
        env -u TMUX tmux -L $server set-option -g status off
        if [[ -n $foreground && -n $background ]]; then
            env -u TMUX tmux -L $server set-option -gw window-style \
                "fg=$foreground,bg=$background"
        fi
        popup_command="env -u TMUX tmux -L ${(q)server} attach-session -d -t ${(q)address}"
    else
        typeset -a launch=(
            env "${muster_private_tmux_environment[@]}"
            tmux -L $server
            start-server
            ';' set-option -g prefix C-a
            ';' unbind-key C-b
            ';' bind-key C-a send-prefix
            ';' set-option -g status off
        )
        if [[ -n $foreground && -n $background ]]; then
            launch+=(
                ';' set-option -gw window-style "fg=$foreground,bg=$background"
            )
        fi
        launch+=(
            ';' new-session
            -s $address
            -c $dir
            -e "MUSTER_WINDOW_SLUG=$o_slug"
            -e "MUSTER_SLUG=$address"
            "${zshctl[argzero]:A}"
            codex tui
            --slug $o_slug
            --seat $o_seat
        )
        popup_command=${(j: :)${(q)launch}}
    fi

    tmux display-popup -c $client -B -E -w 100% -h 100% \
        $popup_command
}
