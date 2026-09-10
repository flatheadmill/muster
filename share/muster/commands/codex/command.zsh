function :help:codex {
    help=$(<${functions_source[:help:codex]:A:h}/help.md)
}

function :args:codex {
    eval "$(args -CU -bx h,help -- "$@")"
}

function codex_daemon_settings {
    typeset slug=$1
    typeset address=${2:-$slug}
    typeset model=${3:-gpt-5.6-sol}
    typeset effort=${4:-}
    typeset code_root=$HOME/code
    typeset pane_root=$HOME/pane
    typeset mcp_url="http://localhost:6502/mcp/$slug"

    muster_state_root
    typeset muster_root=$REPLY
    typeset codex_state=$muster_root/codex
    codex_daemon_socket=$codex_state/app-server.sock
    codex_daemon_nudge_queue=$codex_state/nudges
    codex_daemon_model=$model
    codex_daemon_effort=$effort
    codex_daemon_address=$address
    codex_daemon_cwd=$pane_root/$slug
    # A shared app-server can resume a thread before its pane config is trusted.
    # Carry the window's MCP route on the thread as part of every resume.
    codex_daemon_resume_config=$(jq -cn \
        --arg model "$codex_daemon_model" \
        --arg effort "$codex_daemon_effort" \
        --arg cwd "$codex_daemon_cwd" \
        --arg code_root "$code_root" \
        --arg pane_root "$pane_root" \
        --arg muster_root "$muster_root" \
        --arg window_slug "$slug" \
        --arg agent_slug "$codex_daemon_address" \
        --arg mcp_url "$mcp_url" '
        ({
            model: $model,
            cwd: $cwd,
            runtimeWorkspaceRoots: [$code_root, $pane_root, $muster_root],
            approvalPolicy: "on-request",
            approvalsReviewer: "auto_review",
            sandbox: "workspace-write",
            config: {
                sandbox_workspace_write: {
                    network_access: true,
                    writable_roots: [$code_root, $pane_root, $muster_root]
                },
                shell_environment_policy: {
                    set: {
                        MUSTER_WINDOW_SLUG: $window_slug,
                        MUSTER_SLUG: $agent_slug
                    }
                },
                features: {apps: false},
                mcp_servers: {
                    o: {
                        url: $mcp_url,
                        default_tools_approval_mode: "prompt",
                        tools: {
                            tools: {approval_mode: "approve"},
                            approve: {approval_mode: "approve"}
                        }
                    }
                }
            }
        } + if $effort == "" then {} else {effort: $effort} end)
    ')
    codex_mcp_cli_args=(
        --disable apps
        -c "mcp_servers.o.url=\"$mcp_url\""
        -c 'mcp_servers.o.default_tools_approval_mode="prompt"'
        -c 'mcp_servers.o.tools.tools.approval_mode="approve"'
        -c 'mcp_servers.o.tools.approve.approval_mode="approve"'
    )
    # Remote resume restores permissions configured by the server-side probe.
    # Codex rejects permission overrides supplied by the attaching TUI.
    codex_daemon_cli_args=(
        --cd "$codex_daemon_cwd"
        --model "$codex_daemon_model"
        -c "shell_environment_policy.set.MUSTER_WINDOW_SLUG=\"$slug\""
        -c "shell_environment_policy.set.MUSTER_SLUG=\"$codex_daemon_address\""
        "${(@)codex_mcp_cli_args}"
    )
    [[ -z $codex_daemon_effort ]] || codex_daemon_cli_args+=(
        -c "model_reasoning_effort=\"$codex_daemon_effort\""
    )
}

function codex_pane_configure {
    typeset slug=$1
    typeset codex_dir=~/pane/$slug/.codex
    typeset config=$codex_dir/config.toml
    typeset mcp_url="http://localhost:6502/mcp/$slug"
    typeset stage config_tmp staged_tmp validation

    mkdir -p $codex_dir
    stage=$(mktemp -d $codex_dir/.configure.XXXXXX)
    [[ ! -f $config ]] || cp $config $stage/config.toml

    {
        CODEX_HOME=$stage codex mcp add o --url "$mcp_url" >/dev/null \
            || abend 'fatal: unable to configure Easement MCP for %s' "$slug"

        staged_tmp=$(mktemp $stage/.config.toml.XXXXXX)
        awk '
            { print }
            /^\[mcp_servers\.o\]$/ {
                print "default_tools_approval_mode = \"prompt\""
                print "tools.tools.approval_mode = \"approve\""
                print "tools.approve.approval_mode = \"approve\""
            }
        ' $stage/config.toml > $staged_tmp \
            || abend 'fatal: unable to prepare %s' "$config"
        mv $staged_tmp $stage/config.toml
        staged_tmp=

        validation=$(CODEX_HOME=$stage codex --strict-config --version 2>&1) \
            || abend "fatal: Codex rejected $config:\n$validation"

        config_tmp=$(mktemp $codex_dir/.config.toml.XXXXXX)
        cp $stage/config.toml $config_tmp
        mv $config_tmp $config
        config_tmp=
    } always {
        [[ -z $config_tmp ]] || rm -f $config_tmp
        [[ -z $staged_tmp ]] || rm -f $staged_tmp
        [[ -z $stage ]] || rm -rf $stage
    }
}

function codex_nudge_bin {
    print -r -- ${functions_source[codex_nudge_bin]:A:h:h:h:h:h}/bin/codex-nudge
}

function codex_nudge_relay_bin {
    print -r -- ${functions_source[codex_nudge_relay_bin]:A:h:h:h:h:h}/bin/codex-nudge-relay
}

function codex_session_file {
    typeset slug=$1
    typeset seat=${2:-}
    muster_state_root
    if [[ -n $seat ]]; then
        REPLY=$REPLY/codex/$slug/seats/$seat/sid.json
    else
        REPLY=$REPLY/codex/$slug/sid.json
    fi
}

function codex_seat_config_file {
    typeset slug=$1 seat=$2
    muster_state_root
    REPLY=$REPLY/codex/$slug/seats/$seat/config.json
}

function codex_seat_settings {
    typeset slug=$1 seat=$2
    muster_window_slug $slug
    muster_window_slug $seat

    codex_seat_config_file $slug $seat
    typeset config=$REPLY
    [[ -f $config ]] || abend 'fatal: unknown Codex seat: %s-%s' "$slug" "$seat"

    codex_seat_address=$(jq -er '.address | strings | select(length > 0)' $config 2>/dev/null) \
        || abend 'fatal: Codex seat has no address: %s-%s' "$slug" "$seat"
    codex_seat_model=$(jq -er '.model | strings | select(length > 0)' $config 2>/dev/null) \
        || abend 'fatal: Codex seat has no model: %s-%s' "$slug" "$seat"
    codex_seat_effort=$(jq -er '.effort | strings | select(length > 0)' $config 2>/dev/null) \
        || abend 'fatal: Codex seat has no effort: %s-%s' "$slug" "$seat"

    [[ $codex_seat_address == ${slug}-${seat} ]] \
        || abend 'fatal: Codex seat address does not match %s-%s' "$slug" "$seat"
    muster_address $codex_seat_address
    case $codex_seat_effort in
        (low|medium|high|xhigh) ;;
        (*) abend 'fatal: invalid Codex effort for %s: %s' "$codex_seat_address" "$codex_seat_effort" ;;
    esac
}

function codex_session_id_read {
    typeset sid_file=$1
    [[ -f $sid_file ]] || return 1

    REPLY=$(jq -er 'select(type == "string" and length > 0)' $sid_file 2>/dev/null) \
        || abend 'fatal: invalid codex session id in %s' "$sid_file"
    [[ -n $REPLY ]] \
        || abend 'fatal: invalid codex session id in %s' "$sid_file"
}

function codex_session_start {
    typeset slug=$1
    typeset sid_file=$2
    typeset address=${3:-$slug}
    typeset model=${4:-gpt-5.6-sol}
    typeset effort=${5:-}
    typeset sid_dir=${sid_file:h}
    typeset lock=$sid_dir/sid.lock
    typeset sid_tmp response session_id
    typeset lockfd

    mkdir -p $sid_dir
    touch $lock
    zmodload zsh/system
    zsystem flock -f lockfd $lock

    {
        if codex_session_id_read $sid_file; then
            return
        fi

        sid_tmp=$(mktemp $sid_dir/.sid.json.XXXXXX) \
            || abend 'fatal: unable to prepare codex session id for slug %s' "$slug"

        codex_daemon_settings $slug $address $model $effort
        codex_app_server_ensure $codex_daemon_socket
        response=$(
            "$(codex_nudge_bin)" \
                --socket "$codex_daemon_socket" \
                --start-thread \
                --resume-config "$codex_daemon_resume_config"
        ) || abend 'fatal: unable to start codex session for slug %s' "$slug"

        session_id=$(print -r -- "$response" | jq -er \
            '.threadId | select(type == "string" and length > 0)' 2>/dev/null) \
            || abend 'fatal: Codex returned no session id for slug %s' "$slug"
        [[ -n $session_id ]] \
            || abend 'fatal: Codex returned no session id for slug %s' "$slug"

        jq -Rn --arg sid "$session_id" '$sid' > $sid_tmp \
            || abend 'fatal: unable to write codex session id for slug %s' "$slug"
        codex_session_id_read $sid_tmp
        mv $sid_tmp $sid_file \
            || abend 'fatal: unable to install codex session id for slug %s' "$slug"
        sid_tmp=
        REPLY=$session_id
    } always {
        [[ -z $sid_tmp ]] || rm -f $sid_tmp
        zsystem flock -u $lockfd
    }
}

function codex_app_server_running {
    typeset socket=$1
    [[ -S $socket ]] || return 1
    "$(codex_nudge_bin)" --socket "$socket" --initialize-only >/dev/null 2>&1
}

function codex_nudge_relay_ensure {
    typeset socket=$1
    typeset queue=$2
    typeset state_dir=${socket:h}
    typeset pid_file=$state_dir/nudge-relay.pid
    typeset lock=$state_dir/nudge-relay.lock
    typeset log=$state_dir/nudge-relay.log
    typeset relay_pid

    mkdir -p $state_dir $queue
    touch $lock
    zmodload zsh/system
    typeset lockfd
    zsystem flock -f lockfd $lock

    if [[ -f $pid_file ]]; then
        relay_pid=$(<$pid_file)
        if [[ $relay_pid == <-> ]] && kill -0 $relay_pid 2>/dev/null; then
            zsystem flock -u $lockfd
            return
        fi
    fi

    rm -f $pid_file
    relay_pid=$("$(codex_nudge_relay_bin)" \
        --socket "$socket" \
        --queue "$queue" \
        --start \
        --log "$log") \
        || abend 'fatal: unable to start Codex nudge relay; see %s' "$log"
    print -r -- $relay_pid > $pid_file

    sleep 0.1
    kill -0 $relay_pid 2>/dev/null \
        || abend 'fatal: Codex nudge relay exited during startup; see %s' "$log"
    zsystem flock -u $lockfd
}

function codex_app_server_ensure {
    typeset socket=$1
    typeset state_dir=${socket:h}
    typeset pid_file=$state_dir/app-server.pid
    typeset lock=$state_dir/app-server.lock
    typeset log=$state_dir/app-server.log

    mkdir -p $state_dir ${log:h}
    touch $lock
    zmodload zsh/system
    typeset lockfd
    zsystem flock -f lockfd $lock

    if codex_app_server_running "$socket"; then
        codex_nudge_relay_ensure "$socket" "$codex_daemon_nudge_queue"
        zsystem flock -u $lockfd
        return
    fi

    typeset old_pid signal_error
    [[ -f $pid_file ]] && old_pid=$(<$pid_file)
    if [[ -n $old_pid ]]; then
        [[ $old_pid == <-> ]] \
            || abend 'fatal: invalid Codex app-server pid in %s' "$pid_file"
        if signal_error=$(kill -0 $old_pid 2>&1); then
            abend 'fatal: Codex app-server pid %s is running but %s is unavailable' "$old_pid" "$socket"
        fi
        [[ $signal_error == *'no such process'* ]] \
            || abend 'fatal: unable to establish whether Codex app-server pid %s is running' "$old_pid"
    fi

    # An existing endpoint may belong to a healthy daemon that this caller's
    # sandbox cannot reach. Remove it only when Muster's recorded process is
    # definitively gone; an absent PID or an ownership error proves nothing.
    if [[ -e $socket || -L $socket ]]; then
        [[ ! -L $socket && -n $old_pid ]] \
            || abend 'fatal: shared Codex app-server at %s is unavailable' "$socket"
        rm -f $socket
    fi
    rm -f $pid_file
    typeset server_pid=$(
        "$(codex_nudge_bin)" --socket "$socket" --start-server --log "$log"
    )
    print -r -- $server_pid > $pid_file

    integer attempt
    for attempt in {1..50}; do
        if codex_app_server_running "$socket"; then
            codex_nudge_relay_ensure "$socket" "$codex_daemon_nudge_queue"
            zsystem flock -u $lockfd
            return
        fi
        kill -0 $server_pid 2>/dev/null \
            || abend 'fatal: Codex app-server exited during startup; see %s' "$log"
        sleep 0.1
    done

    abend 'fatal: Codex app-server did not become ready at %s; see %s' "$socket" "$log"
}

function :execute:codex {
    delegate "$@"
}
