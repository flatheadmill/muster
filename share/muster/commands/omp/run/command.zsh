function :help:omp:run {
    help=$(<${functions_source[:help:omp:run]:A:h}/help.md)
}

function :args:omp:run {
    eval "$(args -bx h,help -s s,slug t,topic -- "$@")"
}

function omp_model_selector {
    case $1 in
        (sol) print -r -- 'openai-codex/gpt-5.6-sol:high' ;;
        (opus) print -r -- 'anthropic/claude-opus-5:high' ;;
        (fable) print -r -- 'anthropic/claude-fable-5:high' ;;
        (*) return 1 ;;
    esac
}

function omp_configure_default_model {
    typeset config=$1 selector=$2
    typeset config_path=$config
    if [[ -h $config ]]; then
        config_path=${config:A}
        [[ -e $config_path ]] \
            || abend 'fatal: OMP config symlink has no target: %s' "$config"
    fi

    typeset config_dir=${config_path:h} config_tmp
    mkdir -p $config_dir

    if [[ ! -e $config ]]; then
        config_tmp=$(mktemp $config_dir/.config.yml.XXXXXX) \
            || abend 'fatal: cannot stage %s' "$config"
        {
            cat > $config_tmp <<EOF || abend 'fatal: cannot stage %s' "$config"
modelRoleStorage: project
modelRoles:
  default: $selector
  advisor: openai-codex/gpt-5.6-sol:high
defaultThinkingLevel: high
advisor:
  enabled: true
  syncBacklog: "1"
EOF
            mv $config_tmp $config_path || abend 'fatal: cannot install %s' "$config"
            config_tmp=
        } always {
            [[ -z $config_tmp ]] || rm -f $config_tmp
        }
        return
    fi

    config_tmp=$(mktemp $config_dir/.config.yml.XXXXXX) \
        || abend 'fatal: cannot stage %s' "$config"
    {
        awk -v selector="$selector" '
            /^modelRoles:[[:space:]]*($|#)/ { in_roles = 1; roles_indent = match($0, /[^ ]/) - 1; print; next }
            in_roles && match($0, /[^ ]/) && (match($0, /[^ ]/) - 1) <= roles_indent { in_roles = 0 }
            in_roles && /^[ ]+default:[[:space:]]*/ {
                indent = $0
                sub(/[^ ].*$/, "", indent)
                comment = ""
                if (match($0, /[[:space:]]+#/)) comment = substr($0, RSTART)
                print indent "default: " selector comment
                replaced++
                next
            }
            { print }
            END { if (replaced != 1) exit 42 }
        ' $config_path > $config_tmp \
            || abend 'fatal: %s must contain exactly one modelRoles.default field' "$config"
        mv $config_tmp $config_path || abend 'fatal: cannot install %s' "$config"
        config_tmp=
    } always {
        [[ -z $config_tmp ]] || rm -f $config_tmp
    }
}

function :execute:omp:run {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    [[ $# -eq 0 ]] || abend 'fatal: usage: muster omp run --slug <slug> [--topic <topic>]'
    muster_window_slug $o_slug

    muster_state_root
    typeset state_dir=$REPLY/omp/$o_slug
    typeset active_file=$state_dir/active topic
    if [[ -v o_topic ]]; then
        topic=$o_topic
        muster_window_slug $topic
    else
        [[ -s $active_file ]] || abend 'fatal: no active OMP topic for %s' "$o_slug"
        topic=$(<$active_file)
        muster_window_slug $topic
    fi

    typeset topic_dir=$state_dir/topics/$topic
    [[ -d $topic_dir ]] || abend 'fatal: unknown OMP topic: %s' "$topic"
    [[ -f $topic_dir/model ]] || abend 'fatal: OMP topic has no model: %s' "$topic"
    typeset model=$(<$topic_dir/model)
    typeset selector=$(omp_model_selector $model) \
        || abend 'fatal: invalid OMP model for topic %s: %s' "$topic" "$model"

    [[ -n ${TMUX:-} ]] || abend 'fatal: muster omp run must run inside tmux'
    typeset dir=~/pane/$o_slug
    [[ -d $dir ]] || abend 'fatal: no window directory at %s' "$dir"
    typeset omp_bin=${commands[omp]:-}
    [[ -n $omp_bin ]] || abend 'fatal: omp is not installed'

    typeset server=muster-omp
    typeset current=
    [[ ! -s $active_file ]] || current=$(<$active_file)
    if [[ $current != $topic ]]; then
        env -u TMUX tmux -L $server kill-session -t "=$o_slug" 2>/dev/null
        if env -u TMUX tmux -L $server has-session -t "=$o_slug" 2>/dev/null; then
            abend 'fatal: cannot stop the current OMP session for %s' "$o_slug"
        fi
    fi

    if ! env -u TMUX tmux -L $server has-session -t "=$o_slug" 2>/dev/null; then
        omp_configure_default_model $dir/.omp/config.yml $selector
        mkdir -p $state_dir
        print -r -- $topic > $active_file

        muster_private_tmux_new_session -L $server new-session -d \
            -s $o_slug \
            -c $dir \
            -e "MUSTER_WINDOW_SLUG=$o_slug" \
            -e "MUSTER_SLUG=${o_slug}-omp" \
            $omp_bin \
            --cwd $dir \
            --resume $topic_dir/sid.jsonl \
            || env -u TMUX tmux -L $server has-session -t "=$o_slug" 2>/dev/null \
            || abend 'fatal: cannot launch OMP for %s' "$o_slug"
    fi

    env -u TMUX tmux -L $server set-option -g prefix C-a
    env -u TMUX tmux -L $server unbind-key C-b 2>/dev/null
    env -u TMUX tmux -L $server bind-key C-a send-prefix
    env -u TMUX tmux -L $server set-option -g status off

    typeset client=$(tmux display-message -p '#{client_name}')
    [[ -n $client ]] || abend 'fatal: cannot find the current tmux client'
    tmux display-popup -c $client -B -E -w 100% -h 100% \
        "env -u TMUX tmux -L $server attach-session -d -t $o_slug"
}
