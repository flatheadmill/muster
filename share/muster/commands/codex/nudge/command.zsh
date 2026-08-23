function :help:codex:nudge {
    help=$(<${functions_source[:help:codex:nudge]:A:h}/help.md)
}

function :args:codex:nudge {
    eval "$(args -bx h,help p,probe -s s,slug -- "$@")"
}

function :execute:codex:nudge {
    [[ -v o_slug ]] || abend 'fatal: slug is a required argument'
    muster_window_slug $o_slug

    codex_session_file $o_slug
    typeset sid_file=$REPLY
    codex_session_id_read $sid_file \
        || abend 'fatal: no codex session for slug %s' "$o_slug"
    typeset session_id=$REPLY

    codex_daemon_settings $o_slug
    if (( o_probe )); then
        codex_app_server_ensure $codex_daemon_socket
        "$(codex_nudge_bin)" \
            --socket "$codex_daemon_socket" \
            --thread "$session_id" \
            --resume-config "$codex_daemon_resume_config" \
            --probe
        return
    fi

    typeset prompt=$(cat)
    [[ -n ${prompt//[[:space:]]/} ]] || abend 'fatal: prompt is empty'

    typeset requests=$codex_daemon_nudge_queue/requests
    typeset responses=$codex_daemon_nudge_queue/responses
    mkdir -p $requests $responses

    zmodload zsh/datetime
    typeset stamp=${EPOCHREALTIME//./-}.$$.${RANDOM}.json
    typeset request=$requests/$stamp
    typeset response=$responses/$stamp
    typeset staged=$(mktemp $requests/.request.XXXXXX) \
        || abend 'fatal: unable to stage Codex nudge'

    jq -cn \
        --arg thread "$session_id" \
        --argjson resumeConfig "$codex_daemon_resume_config" \
        --arg prompt "$prompt" \
        '{ thread: $thread, resumeConfig: $resumeConfig, prompt: $prompt }' \
        > $staged || abend 'fatal: unable to encode Codex nudge'
    mv $staged $request || abend 'fatal: unable to queue Codex nudge'
    staged=

    integer attempt
    for attempt in {1..100}; do
        if [[ -f $response ]]; then
            typeset result=$(<$response)
            rm -f $response
            if [[ $(jq -r '.ok // false' <<< "$result") == true ]]; then
                jq -r '.output // empty' <<< "$result"
                return
            fi
            typeset error=$(jq -r '.error // "Codex nudge failed"' <<< "$result")
            abend '%s' "$error"
        fi
        sleep 0.05
    done

    abend 'fatal: Codex nudge relay did not answer; the nudge remains queued'
}
