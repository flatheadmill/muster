function :help:collaboration {
    help=$(<${functions_source[:help:collaboration]:A:h}/help.md)
}

function :args:collaboration {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:collaboration {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    [[ $# -eq 0 ]] || abend 'fatal: usage: muster collaboration --slug <slug>'
    [[ -n ${TMUX:-} ]] || abend 'fatal: muster collaboration must run inside tmux'
    muster_window_slug $o_slug

    typeset dir=~/pane/$o_slug
    [[ -d $dir ]] || abend 'fatal: no window directory at %s' "$dir"
    dir=${dir:A}

    typeset server=muster-collaboration foreground= background=
    typeset shell=${commands[zsh]:-}
    [[ -n $shell ]] || abend 'fatal: zsh is not installed'
    typeset client=$(tmux display-message -p '#{client_name}')
    [[ -n $client ]] || abend 'fatal: cannot find the current tmux client'
    if muster_tmux_terminal_color MUSTER_TERMINAL_FOREGROUND; then
        foreground=$REPLY
    fi
    if muster_tmux_terminal_color MUSTER_TERMINAL_BACKGROUND; then
        background=$REPLY
    fi

    if ! env -u TMUX tmux -L $server has-session -t "=$o_slug" 2>/dev/null; then
        typeset -a launch=(
            -L $server
            start-server
            ';' set-option -g prefix C-a
            ';' unbind-key C-b
            ';' bind-key C-a send-prefix
            ';' set-option -g status off
            ';' set-option -g default-shell $shell
            ';' set-environment -g SHELL $shell
        )
        if [[ -n $foreground && -n $background ]]; then
            launch+=(
                ';' set-option -gw window-style "fg=$foreground,bg=$background"
            )
        fi
        launch+=(
            ';' new-session
            -d
            -s $o_slug
            -c $dir
            -e "MUSTER_WINDOW_SLUG=$o_slug"
            -e "MUSTER_SLUG=$o_slug"
            "${zshctl[argzero]:A}"
            codex tui
            --slug $o_slug
        )
        muster_private_tmux_new_session "${(@)launch}" \
            || abend 'fatal: unable to create collaboration session for %s' "$o_slug"
    else
        env -u TMUX tmux -L $server set-option -g prefix C-a
        env -u TMUX tmux -L $server unbind-key C-b 2>/dev/null
        env -u TMUX tmux -L $server bind-key C-a send-prefix
        env -u TMUX tmux -L $server set-option -g status off
        env -u TMUX tmux -L $server set-option -g default-shell $shell
        env -u TMUX tmux -L $server set-environment -g SHELL $shell
        if [[ -n $foreground && -n $background ]]; then
            env -u TMUX tmux -L $server set-option -gw window-style \
                "fg=$foreground,bg=$background"
        fi
    fi

    tmux display-popup -c $client -B -E -w 100% -h 100% \
        "env -u TMUX tmux -L ${(q)server} attach-session -d -t ${(q)o_slug}"
}
