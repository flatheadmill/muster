function :help:omp:run {
    help=$(<${functions_source[:help:omp:run]:A:h}/help.md)
}

function :args:omp:run {
    eval "$(args -bx h,help -s s,slug ,seat -- "$@")"
}

function :execute:omp:run {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    [[ $# -eq 0 ]] || abend 'fatal: usage: muster omp run --slug <slug> [--seat audit|bench]'
    muster_window_slug $o_slug
    typeset seat=${o_seat:-audit}
    [[ $seat == audit || $seat == bench ]] || abend 'fatal: OMP seat must be audit or bench'

    [[ -n ${TMUX:-} ]] || abend 'fatal: muster omp run must run inside tmux'
    typeset dir=$HOME/pane/$o_slug
    muster_omp_directory $dir
    [[ -d $dir ]] || abend 'fatal: no window directory at %s' "$dir"
    muster_omp_state $o_slug
    typeset layout=$REPLY
    muster_omp_collisions $o_slug
    muster_messages_configure
    [[ -z ${MUSTER_MESSAGES_SSH:-} ]] ||
        abend 'fatal: OMP seats require local message storage'
    muster_state_root
    typeset state=$REPLY
    muster_omp_directory $state/messages
    muster_omp_directory $state/messages/${o_slug}-omp
    if [[ $layout == legacy ]] || muster_omp_exists $state/messages/${o_slug}-omp; then
        abend 'fatal: OMP room requires conversion; stop the room and run: muster omp migrate --slug %s' "$o_slug"
    fi
    if muster_omp_session_exists $o_slug; then
        abend 'fatal: stop the legacy OMP session %s before launching a seat' "$o_slug"
    fi
    muster_omp_declaration $o_slug $seat
    typeset policy=$REPLY selector effort
    selector=$(jq -er '.modelRoles.default' <<< $policy)
    effort=$(jq -er '
        (.modelRoles.default | capture(":(?<effort>off|minimal|low|medium|high|xhigh|auto)$").effort)
        // .defaultThinkingLevel
    ' <<< $policy)
    typeset config=$dir/.omp/$seat/config.json
    typeset omp_bin=${commands[omp]:-}
    [[ -n $omp_bin ]] || abend 'fatal: omp is not installed'
    typeset messages_prompt=${functions_source[:execute:omp:run]:A:h}/messages.md
    [[ -f $messages_prompt ]] || abend 'fatal: OMP messages prompt is missing: %s' "$messages_prompt"

    typeset address=${o_slug}-${seat}
    typeset state_dir=$state/omp/$o_slug/$seat
    typeset session_file=$state_dir/sid.jsonl
    if [[ ! -d $state_dir ]] && muster_omp_exists $state/messages/$address; then
        abend 'fatal: mailbox exists without the OMP seat: %s' "$state/messages/$address"
    fi
    muster_messages_dir $address

    if [[ ! -e $session_file ]]; then
        mkdir -p $state_dir || abend 'fatal: cannot create OMP seat: %s' "$state_dir"
        typeset session_id=$(uuidgen) || abend 'fatal: cannot generate OMP session ID'
        session_id=${(L)session_id}
        typeset timestamp=$(date -u '+%Y-%m-%dT%H:%M:%S.000Z')
        typeset staged=$(mktemp $state_dir/.sid.XXXXXX) || abend 'fatal: cannot stage OMP session'

        # OMP resumes named files but cannot create one at a requested path.
        {
            jq -cn \
                --arg id $session_id \
                --arg timestamp $timestamp \
                --arg cwd $dir \
                '{type:"session", version:3, id:$id, timestamp:$timestamp, cwd:$cwd}' \
                > $staged || abend 'fatal: cannot create OMP session for %s' "$address"
            ln $staged $session_file 2>/dev/null || muster_omp_file $session_file
        } always {
            rm -f $staged
        }
    fi

    typeset server=muster-omp
    if ! muster_omp_session_exists $address; then
        muster_private_tmux_new_session -L $server new-session -d \
            -s $address \
            -c $dir \
            -e "MUSTER_WINDOW_SLUG=$o_slug" \
            -e "MUSTER_SLUG=$address" \
            $omp_bin \
            --cwd $dir \
            --config $config \
            --model $selector \
            --thinking $effort \
            --append-system-prompt $messages_prompt \
            --resume $session_file \
            || muster_omp_session_exists $address \
            || abend 'fatal: cannot launch OMP for %s' "$address"
    fi

    env -u TMUX tmux -L $server set-option -g prefix C-a
    env -u TMUX tmux -L $server unbind-key C-b 2>/dev/null
    env -u TMUX tmux -L $server bind-key C-a send-prefix
    env -u TMUX tmux -L $server set-option -g status off

    typeset client=$(tmux display-message -p '#{client_name}')
    [[ -n $client ]] || abend 'fatal: cannot find the current tmux client'
    tmux display-popup -c $client -B -E -s 'bg=black,fg=white' -w 100% -h 100% \
        "env -u TMUX tmux -L ${(q)server} attach-session -d -t ${(q)address}"
}
