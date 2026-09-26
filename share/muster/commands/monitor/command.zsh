function :help:monitor {
    help=$(<${functions_source[:help:monitor]:A:h}/help.md)
}

function :args:monitor {
    integer monitor_separator=${@[(ie)--]}
    integer monitor_arguments=$(( $# - monitor_separator ))
    eval "$(args -bx h,help -s s,slug -- "$@")"
}

function :execute:monitor {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    muster_window_slug $o_slug
    (( monitor_arguments > 0 && $# == monitor_arguments )) ||
        abend 'fatal: usage: muster monitor --slug <window> -- command argument ...'

    emulate -L zsh
    setopt localtraps
    unsetopt bgnice
    typeset muster=${zshctl[argzero]:A} line
    integer producer=0 input_fd=0 nudge=0 interrupted=0 result=0 read_result=0
    integer producer_signalled=0
    # A trapped signal interrupts read/wait. Only our direct producer is owned;
    # it must handle its own descendants and terminate cooperatively.
    trap 'interrupted=130; if (( producer )); then kill -INT $producer 2>/dev/null; producer_signalled=1; fi' INT
    trap 'interrupted=143; if (( producer )); then kill -TERM $producer 2>/dev/null; producer_signalled=1; fi' TERM
    trap 'interrupted=129; if (( producer )); then kill -HUP $producer 2>/dev/null; producer_signalled=1; fi' HUP
    trap 'result=1' PIPE

    {
        coproc { trap - INT TERM HUP; exec "$@" </dev/null; }
        producer=$!
        # Retain the read end even after a short-lived coprocess exits.
        if exec {input_fd}<&p; then
            while (( ! interrupted && ! result )); do
                line=
                IFS= read -r -u $input_fd line
                read_result=$?
                (( interrupted )) && break
                if (( read_result )); then
                    if [[ -n $line ]]; then
                        print -u2 -- 'fatal: monitor producer ended with an unterminated stdout record'
                        result=1
                    fi
                    break
                fi
                [[ -n ${line//[[:space:]]/} ]] || continue
                print -r -- "$line" || { result=1; break; }
                # A here-string adds the framing LF, which codex nudge removes.
                # Waiting on a background invocation lets traps forward signals
                # while acceptance is pending; we still reap it before returning.
                "$muster" codex nudge --slug "$o_slug" <<< "$line" >/dev/null &
                nudge=$!
                while true; do
                    wait $nudge
                    result=$?
                    kill -0 $nudge 2>/dev/null || break
                done
                nudge=0
                (( interrupted )) && break
                if (( result )); then
                    print -u2 -- 'fatal: monitor nudge failed; delivery is uncertain; stopping without retry'
                    break
                fi
            done
        else
            result=1
        fi
    } always {
        (( input_fd )) && exec {input_fd}<&-
        if (( producer )); then
            if (( interrupted && ! producer_signalled )); then
                kill -$(( interrupted - 128 )) $producer 2>/dev/null
            elif (( result && ! interrupted )); then
                kill -TERM $producer 2>/dev/null
            fi
            # Repeated signals can interrupt wait; do not return with a live child.
            while true; do
                wait $producer
                read_result=$?
                kill -0 $producer 2>/dev/null || break
            done
            (( result || interrupted )) || result=$read_result
        fi
    }
    (( interrupted )) && return $interrupted
    return $result
}
