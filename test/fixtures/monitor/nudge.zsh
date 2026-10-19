function :execute:codex:nudge {
    zmodload zsh/zselect
    typeset capture=$MONITOR_TEST_ROOT/nudge.$$
    print -r -- $$ > $capture.pid
    # Keep the bytes on disk: command substitution would discard the final LF.
    cat > $capture.input
    jq -cn --args '$ARGS.positional' -- "$@" > $capture.args
    jq -cn --argjson pid $$ --slurpfile args $capture.args --rawfile text $capture.input \
        '{pid:$pid, args:$args[0], text:$text}' >> $MONITOR_TEST_ROOT/calls
    print -r -- "begin $$" >> $MONITOR_TEST_ROOT/events
    print -r -- $$ > $MONITOR_TEST_ROOT/nudging

    if [[ ${MONITOR_TEST_HOLD:-0} == 1 ]]; then
        integer attempts
        for (( attempts=0; attempts < 1000; attempts++ )); do
            [[ ! -e $MONITOR_TEST_ROOT/release ]] || break
            zselect -t 1
        done
        [[ -e $MONITOR_TEST_ROOT/release ]] || return 124
    fi
    print -r -- '{"success":"must not leak"}'
    print -ru2 -- 'nudge diagnostic'
    print -r -- "end $$" >> $MONITOR_TEST_ROOT/events
    return ${MONITOR_TEST_FAIL:-0}
}
