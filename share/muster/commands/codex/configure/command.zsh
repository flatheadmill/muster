function :help:codex:configure {
    help=$(<${functions_source[:help:codex:configure]:A:h}/help.md)
}

function :args:codex:configure {
    typeset parsed
    parsed=$(args -bx h,help ,clear -s s,slug m,model e,effort -- "$@") || exit $?
    eval "$parsed"
}

function :execute:codex:configure {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    [[ $# -eq 0 ]] || abend 'fatal: unexpected positional arguments'
    muster_window_slug "$o_slug"
    if (( o_clear )); then
        [[ ! -v o_model && ! -v o_effort ]] \
            || abend 'fatal: --clear cannot be combined with --model or --effort'
    else
        [[ -v o_model && -v o_effort ]] \
            || abend 'fatal: --model and --effort are required together (or use --clear)'
    fi

    typeset value config staged=
    if (( ! o_clear )); then
        value=$(jq -cn --arg model "$o_model" --arg effort "$o_effort" \
            '{model: $model, effort: $effort}' | codex_main_config_validate 2>/dev/null) \
            || abend 'fatal: specify a nonempty model and effort low, medium, high, or xhigh'
    fi
    codex_main_config_file "$o_slug"
    config=$REPLY
    if [[ -e $config || -L $config ]]; then
        [[ -f $config && ! -L $config ]] \
            || abend 'fatal: main Codex configuration must be an ordinary file: %s' "$config"
    fi

    if (( o_clear )); then
        if [[ -e $config ]]; then
            rm -- "$config" || abend 'fatal: cannot clear main Codex configuration: %s' "$config"
        fi
        print -r -- "Cleared main Codex preference for $o_slug; defaults apply on the next Muster resume or nudge."
    else
        mkdir -p -- "${config:h}" \
            || abend 'fatal: cannot create Codex state directory: %s' "${config:h}"
        {
            staged=$(mktemp "${config:h}/.config.XXXXXX") \
                || abend 'fatal: cannot stage main Codex configuration: %s' "$config"
            print -r -- "$value" > "$staged" \
                || abend 'fatal: cannot write main Codex configuration: %s' "$config"
            mv -- "$staged" "$config" \
                || abend 'fatal: cannot install main Codex configuration: %s' "$config"
            staged=
        } always {
            [[ -z $staged ]] || rm -f -- "$staged"
        }
        print -r -- "Saved main Codex preference for $o_slug; it applies on the next Muster resume or nudge."
    fi
}
