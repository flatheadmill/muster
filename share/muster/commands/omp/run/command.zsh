function :help:omp:run {
    help=$(<${functions_source[:help:omp:run]:A:h}/help.md)
}

function :args:omp:run {
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:omp:run {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    [[ $# -eq 0 ]] || abend 'fatal: usage: muster omp run --slug <slug>'
    muster_window_slug $o_slug

    [[ -n ${TMUX:-} ]] || abend 'fatal: muster omp run must run inside tmux'
    typeset dir=~/pane/$o_slug
    [[ -d $dir ]] || abend 'fatal: no window directory at %s' "$dir"
    typeset omp_bin=${commands[omp]:-}
    [[ -n $omp_bin ]] || abend 'fatal: omp is not installed'
    typeset messages_prompt=${functions_source[:execute:omp:run]:A:h}/messages.md
    [[ -f $messages_prompt ]] || abend 'fatal: OMP messages prompt is missing: %s' "$messages_prompt"

    typeset model_roles selector
    model_roles=$(cd $dir && $omp_bin config get modelRoles) \
        || abend 'fatal: cannot read OMP model roles for %s' "$o_slug"
    selector=$(jq -er '.default | strings | select(length > 0)' <<< $model_roles) \
        || abend 'fatal: OMP default model is not configured for %s' "$o_slug"

    muster_state_root
    typeset state_dir=$REPLY/omp/$o_slug
    typeset session_file=$state_dir/sid.jsonl

    if [[ ! -e $session_file ]]; then
        mkdir -p $state_dir
        typeset session_id=$(uuidgen | tr '[:upper:]' '[:lower:]')
        typeset timestamp=$(date -u '+%Y-%m-%dT%H:%M:%S.000Z')

        # OMP resumes named files but cannot create one at a requested path.
        jq -cn \
            --arg id $session_id \
            --arg timestamp $timestamp \
            --arg cwd $dir \
            '{type:"session", version:3, id:$id, timestamp:$timestamp, cwd:$cwd}' \
            > $session_file \
            || abend 'fatal: cannot create OMP session for %s' "$o_slug"
    fi

    typeset server=muster-omp
    if ! env -u TMUX tmux -L $server has-session -t "=$o_slug" 2>/dev/null; then
        muster_private_tmux_new_session -L $server new-session -d \
            -s $o_slug \
            -c $dir \
            -e "MUSTER_WINDOW_SLUG=$o_slug" \
            -e "MUSTER_SLUG=${o_slug}-omp" \
            $omp_bin \
            --cwd $dir \
            --model $selector \
            --append-system-prompt $messages_prompt \
            --resume $session_file \
            || env -u TMUX tmux -L $server has-session -t "=$o_slug" 2>/dev/null \
            || abend 'fatal: cannot launch OMP for %s' "$o_slug"
    fi

    env -u TMUX tmux -L $server set-option -g prefix C-a
    env -u TMUX tmux -L $server unbind-key C-b 2>/dev/null
    env -u TMUX tmux -L $server bind-key C-a send-prefix
    env -u TMUX tmux -L $server set-option -g status off

    typeset client=$(tmux display-message -p '#{client_name}')
    [[ -n $client ]] || abend 'fatal: cannot find the current tmux client'
    tmux display-popup -c $client -B -E -s 'bg=black,fg=white' -w 100% -h 100% \
        "env -u TMUX tmux -L $server attach-session -d -t $o_slug"
}
