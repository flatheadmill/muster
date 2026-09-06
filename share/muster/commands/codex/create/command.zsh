function :help:codex:create {
    help=$(<${functions_source[:help:codex:create]:A:h}/help.md)
}

function :args:codex:create {
    eval "$(args -bx h,help -s s,slug n,seat m,model e,effort -- "$@")"
}

function :execute:codex:create {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    [[ -v o_seat ]] || abend 'fatal: --seat is required'
    [[ -v o_effort ]] || abend 'fatal: --effort is required'
    [[ $# -eq 0 ]] || abend 'fatal: usage: muster codex create --slug <slug> --seat <seat> [--model <model>] --effort <low|medium|high|xhigh>'

    muster_window_slug $o_slug
    muster_window_slug $o_seat
    [[ $o_seat != codex ]] || abend 'fatal: codex is the reserved default seat'
    case $o_effort in
        (low|medium|high|xhigh) ;;
        (*) abend 'fatal: effort must be one of low, medium, high, or xhigh' ;;
    esac

    typeset pane_dir=~/pane/$o_slug
    [[ -d $pane_dir ]] \
        || abend 'fatal: no window directory at %s; create the window before creating a Codex seat' "$pane_dir"

    typeset address=${o_slug}-${o_seat}
    typeset model=${o_model:-gpt-5.6-sol}
    [[ -n $model ]] || abend 'fatal: model must not be empty'
    muster_state_root
    typeset seats_dir=$REPLY/codex/$o_slug/seats
    typeset seat_dir=$seats_dir/$o_seat
    [[ ! -e $seat_dir ]] || abend 'fatal: Codex seat already exists: %s' "$address"

    mkdir -p $seats_dir
    typeset staged=$(mktemp -d $seats_dir/.${o_seat}.XXXXXX) \
        || abend 'fatal: unable to stage Codex seat: %s' "$address"
    {
        jq -cn \
            --arg address "$address" \
            --arg model "$model" \
            --arg effort "$o_effort" \
            '{address: $address, model: $model, effort: $effort}' \
            > $staged/config.json \
            || abend 'fatal: unable to encode Codex seat: %s' "$address"
        chmod 600 $staged/config.json

        codex_session_start \
            $o_slug \
            $staged/sid.json \
            $address \
            $model \
            $o_effort
        codex_session_id_read $staged/sid.json
        typeset session_id=$REPLY

        mv $staged $seat_dir \
            || abend 'fatal: unable to install Codex seat: %s' "$address"
        staged=

        jq -cn \
            --arg address "$address" \
            --arg threadId "$session_id" \
            --arg model "$model" \
            --arg effort "$o_effort" \
            '{address: $address, threadId: $threadId, model: $model, effort: $effort}'
    } always {
        [[ -z $staged ]] || rm -rf $staged
    }
}
