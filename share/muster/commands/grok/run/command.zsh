function :help:grok:run {
    help=$(<${functions_source[:help:grok:run]:A:h}/help.md)
}

function :args:grok:run {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:grok:run {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    [[ $# -eq 0 ]] || abend 'fatal: usage: muster grok run --slug <slug>'
    [[ -n ${TMUX:-} ]] || abend 'fatal: muster grok run must run inside tmux'
    muster_window_slug $o_slug

    typeset dir=~/pane/$o_slug
    [[ -d $dir ]] || abend 'fatal: no window directory at %s' "$dir"
    dir=${dir:A}

    grok_state_dir $o_slug
    typeset state_dir=$REPLY
    grok_session_id_read $state_dir/sid \
        || abend 'fatal: no Grok session for window: %s' "$o_slug"
    typeset session_id=$REPLY address=${o_slug}-grok

    typeset grok_bin=${commands[grok]:-}
    [[ -n $grok_bin ]] || abend 'fatal: grok is not installed'
    grok_session_dir $dir $session_id
    typeset -a grok_args=( --cwd $dir --fullscreen --trust )
    if [[ -d $REPLY ]]; then
        grok_args+=( --resume $session_id )
    else
        grok_args+=( --session-id $session_id )
    fi

    typeset server=muster-grok popup_command foreground= background=
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
            $grok_bin
            "${(@)grok_args}"
        )
        popup_command=${(j: :)${(q)launch}}
    fi

    tmux display-popup -c $client -B -E -w 100% -h 100% \
        $popup_command
}
