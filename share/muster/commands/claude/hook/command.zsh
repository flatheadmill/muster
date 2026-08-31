function :args:claude:hook {
    eval "$(args -- "$@")"
}

function :execute:claude:hook {
    typeset payload=$(cat)
    typeset slug=${MUSTER_SLUG:-}
    typeset when=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    muster_state_root
    typeset log=$REPLY/claude/hooks.log
    mkdir -p ${log:h}
    touch $log

    typeset line=$(jq -cn \
        --arg when "$when" \
        --arg slug "$slug" \
        --argjson what "$payload" \
        '{when: $when, slug: $slug, what: $what}')
    zmodload zsh/system
    integer fd
    zsystem flock -f fd $log
    printf '%s\n' "$line" >> $log

    typeset decision=$(jq -c '
        if .hook_event_name == "PreToolUse"
           and .tool_input.who == "wicket"
           and .tool_input.f == "zsh"
           and .tool_input.args.escalate == true
        then {
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "ask",
                permissionDecisionReason: (
                    "Escalated (unsandboxed) Wicket zsh on "
                    + (.tool_input.args.where // "?") + ": "
                    + (.tool_input.args.command // "?")
                )
            }
        }
        else empty end
    ' <<< "$payload")
    [[ -n $decision ]] && printf '%s\n' "$decision"
    return 0
}
