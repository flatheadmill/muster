function :help:rename {
    help=$(<${functions_source[:help:rename]:A:h}/help.md)
}

function :args:rename {
    eval "$(args -bx h,help n,dry-run -s s,slug t,to -- "$@")"
}

function muster_rename_exists {
    [[ -e $1 || -L $1 ]]
}

function muster_rename_add_move {
    typeset source=$1 destination=$2
    muster_rename_exists $destination &&
        abend 'fatal: rename destination already exists: %s' "$destination"
    muster_rename_guard_destinations+=( $destination )
    muster_rename_exists $source || return 0
    [[ ! -L $source ]] ||
        abend 'fatal: rename source must not be a symbolic link: %s' "$source"
    muster_rename_sources+=( $source )
    muster_rename_destinations+=( $destination )
}

function muster_rename_revalidate_plan {
    typeset source destination entry name
    integer index
    for entry in $muster_rename_state/messages/*(N); do
        name=${entry:t}
        [[ $name != $o_to && $name != $o_to-* ]] || {
            print -u2 -- "fatal: destination message address appeared during preflight: $name"
            return 1
        }
    done
    for destination in $muster_rename_guard_destinations; do
        ! muster_rename_exists $destination || {
            print -u2 -- "fatal: rename destination appeared during preflight: $destination"
            return 1
        }
    done
    if (( ${#muster_rename_sources} )); then
        for index in {1..${#muster_rename_sources}}; do
            source=$muster_rename_sources[$index]
            [[ -e $source && ! -L $source ]] || {
                print -u2 -- "fatal: rename source changed during preflight: $source"
                return 1
            }
        done
    fi
}

function muster_rename_require_session_absent {
    typeset server=$1 name=$2 description=$3
    env -u TMUX tmux -L $server has-session -t "=$name" 2>/dev/null &&
        abend 'fatal: %s participant session exists: %s' "$description" "$name"
}

function muster_rename_backup {
    typeset file=$1 backup=$muster_rename_transaction/${#muster_rename_backup_files}
    cp -p $file $backup || return
    muster_rename_backup_files+=( $file )
    muster_rename_backups+=( $backup )
    printf '%s\t%s\n' "$backup" "$file" >> $muster_rename_transaction/backups
}

function muster_rename_install {
    typeset file=$1 staged=$2 mode
    mode=$(stat -f '%Lp' $file) || return
    chmod $mode $staged && mv $staged $file
}

function muster_rename_replace_literal {
    typeset file=$1 old=$2 new=$3 staged
    [[ -f $file ]] || return 0
    grep -Fq -- $old $file || return 0
    muster_rename_backup $file || return
    staged=$(mktemp ${file:h}/.rename.XXXXXX) || return
    awk -v old="$old" -v new="$new" '
        {
            line = $0
            while ((at = index(line, old)) != 0) {
                line = substr(line, 1, at - 1) new substr(line, at + length(old))
            }
            print line
        }
    ' $file > $staged || { rm -f $staged; return 1; }
    muster_rename_install $file $staged || { rm -f $staged; return 1; }
}

function muster_rename_seat_config {
    typeset file=$1 staged
    typeset seat=${file:h:t}
    typeset old_address=${o_slug}-${seat} new_address=${o_to}-${seat}
    [[ $(jq -er '.address' $file 2>/dev/null) == $old_address ]] || return 1
    muster_rename_backup $file || return
    staged=$(mktemp ${file:h}/.config.XXXXXX) || return
    jq -c --arg address "$new_address" '.address = $address' $file > $staged || {
        rm -f $staged
        return 1
    }
    muster_rename_install $file $staged || { rm -f $staged; return 1; }
}

function muster_rename_mcp_json {
    typeset file=$1 old_url=$2 new_url=$3 staged
    [[ -f $file ]] || return 0
    [[ $(jq -er '.mcpServers.o.url // empty' $file 2>/dev/null) == $old_url ]] || return 0
    muster_rename_backup $file || return
    staged=$(mktemp ${file:h}/.mcp.XXXXXX) || return
    jq --arg url "$new_url" '.mcpServers.o.url = $url' $file > $staged || {
        rm -f $staged
        return 1
    }
    muster_rename_install $file $staged || { rm -f $staged; return 1; }
}

function muster_rename_claude_project {
    typeset file=$1 old=$2 new=$3 staged
    [[ -f $file ]] || return 0
    jq -e --arg old "$old" '.projects | objects | has($old)' $file >/dev/null 2>&1 || return 0
    ! jq -e --arg new "$new" '.projects | objects | has($new)' $file >/dev/null 2>&1 || return 1
    muster_rename_backup $file || return
    staged=$(mktemp ${file:h}/.claude.XXXXXX) || return
    jq --arg old "$old" --arg new "$new" \
        '.projects[$new] = .projects[$old] | del(.projects[$old])' \
        $file > $staged || {
        rm -f $staged
        return 1
    }
    muster_rename_install $file $staged || { rm -f $staged; return 1; }
}

function muster_rename_wicket_config {
    typeset file=$1 old=$2 new=$3 staged
    [[ -f $file ]] || return 0
    awk -v old="$old" '
        $0 == "writable " old || index($0, "writable " old "/") == 1 { found = 1 }
        END { exit !found }
    ' $file || return 0
    muster_rename_backup $file || return
    staged=$(mktemp ${file:h}/.sandbox.XXXXXX) || return
    awk -v old="$old" -v new="$new" '
        {
            prefix = "writable " old
            if ($0 == prefix || index($0, prefix "/") == 1) {
                print "writable " new substr($0, length(prefix) + 1)
            } else {
                print
            }
        }
    ' $file > $staged || { rm -f $staged; return 1; }
    muster_rename_install $file $staged || { rm -f $staged; return 1; }
}

function muster_rename_require_idle_threads {
    typeset socket=$muster_rename_state/codex/app-server.sock thread response thread_status
    muster_rename_exists $socket || return 0
    muster_rename_codex_server=1
    for thread in $muster_rename_thread_ids; do
        response=$("${zshctl[argzero]:A:h}/codex-nudge" \
            --socket $socket --thread $thread --read-thread) ||
            return 1
        thread_status=$(jq -er '.status.type' <<< $response 2>/dev/null) || return 1
        [[ $thread_status == idle || $thread_status == notLoaded ]] || {
            print -u2 -- "fatal: Codex thread is not idle: $thread ($thread_status)"
            return 1
        }
    done
}

function muster_rename_reconfigure_threads {
    typeset slug=$1 expected_cwd=${2:-}
    typeset seat sid_file expected_sid response thread_status cwd
    typeset -a args

    for seat in '' $muster_rename_seats; do
        if [[ -n $seat ]]; then
            sid_file=$muster_rename_state/codex/$slug/seats/$seat/sid.json
            args=( --slug $slug --seat $seat --probe )
            [[ -f $sid_file && ! -L $sid_file ]] || return 1
        else
            sid_file=$muster_rename_state/codex/$slug/sid.json
            args=( --slug $slug --probe )
            [[ -f $sid_file && ! -L $sid_file ]] || continue
        fi
        expected_sid=$(jq -er 'strings | select(length > 0)' $sid_file 2>/dev/null) ||
            return 1
        response=$("${zshctl[argzero]:A}" codex nudge "${(@)args}") || return 1
        [[ $(jq -er '.threadId' <<< $response 2>/dev/null) == $expected_sid ]] || return 1
        thread_status=$(jq -er '.status.type' <<< $response 2>/dev/null) || return 1
        [[ $thread_status == idle ]] || {
            print -u2 -- "fatal: Codex thread is not idle: $expected_sid ($thread_status)"
            return 1
        }
        if [[ -n $expected_cwd ]]; then
            cwd=$(jq -er '.cwd' <<< $response 2>/dev/null) || return 1
            [[ $cwd == $expected_cwd ]] || {
                print -u2 -- \
                    "fatal: Codex thread retained the wrong directory: $expected_sid ($cwd)"
                return 1
            }
        fi
    done
}

function muster_rename_apply {
    integer moved=0 committed=0 index
    typeset source destination pane window config
    {
        if (( ${#muster_rename_sources} )); then
            for index in {1..${#muster_rename_sources}}; do
                printf '%s\t%s\n' \
                    "$muster_rename_sources[$index]" \
                    "$muster_rename_destinations[$index]" \
                    >> $muster_rename_transaction/moves
            done
        fi
        if (( ${#muster_rename_sources} )); then
            for index in {1..${#muster_rename_sources}}; do
                source=$muster_rename_sources[$index]
                destination=$muster_rename_destinations[$index]
                mv $source $destination || return 1
                (( moved++ ))
            done
        fi

        typeset old_url=http://localhost:6502/mcp/$o_slug
        typeset new_url=http://localhost:6502/mcp/$o_to
        typeset pane_dir=$HOME/pane/$o_to
        muster_rename_replace_literal \
            $pane_dir/.codex/config.toml \
            "${old_url}\"" \
            "${new_url}\"" || return 1
        muster_rename_mcp_json $pane_dir/.mcp.json $old_url $new_url || return 1
        for config in $muster_rename_state/codex/$o_to/seats/*/config.json(N.); do
            muster_rename_seat_config $config || return 1
        done
        muster_rename_wicket_config \
            $HOME/.local/state/wicket/$o_to/sandbox.conf \
            $muster_rename_old_pane \
            $muster_rename_new_pane || return 1
        muster_rename_claude_project \
            $muster_rename_claude_config \
            $muster_rename_old_pane \
            $muster_rename_new_pane || return 1
        muster_rename_replace_literal \
            $muster_rename_codex_config \
            "projects.\"${muster_rename_old_pane}\"" \
            "projects.\"${muster_rename_new_pane}\"" || return 1
        muster_rename_replace_literal \
            $muster_rename_grok_trust \
            "[folders.\"${muster_rename_old_pane}\"]" \
            "[folders.\"${muster_rename_new_pane}\"]" || return 1

        for pane in $muster_rename_puzzle_panes; do
            tmux set-option -p -t $pane @puzzle-slug $o_to || return 1
            muster_rename_changed_panes+=( $pane )
        done
        for window in $muster_rename_windows; do
            tmux rename-window -t $window $o_to || return 1
            muster_rename_changed_windows+=( $window )
        done
        committed=1
    } always {
        if (( ! committed )); then
            for window in $muster_rename_changed_windows; do
                tmux rename-window -t $window $o_slug 2>/dev/null ||
                    muster_rename_rollback_failed=1
            done
            for pane in $muster_rename_changed_panes; do
                tmux set-option -p -t $pane @puzzle-slug $o_slug 2>/dev/null ||
                    muster_rename_rollback_failed=1
            done
            if (( ${#muster_rename_backup_files} )); then
                for index in {${#muster_rename_backup_files}..1}; do
                    cp -p \
                        $muster_rename_backups[$index] \
                        $muster_rename_backup_files[$index] \
                        2>/dev/null || muster_rename_rollback_failed=1
                done
            fi
            if (( moved )); then
                for index in {$moved..1}; do
                    mv \
                        $muster_rename_destinations[$index] \
                        $muster_rename_sources[$index] \
                        2>/dev/null || muster_rename_rollback_failed=1
                done
            fi
        fi
    }
    (( committed ))
}

function :execute:rename {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    [[ -v o_to ]] || abend 'fatal: --to is required'
    [[ $# -eq 0 ]] ||
        abend 'fatal: usage: muster rename --slug <old> --to <new> [--dry-run]'
    [[ -n ${TMUX:-} ]] || abend 'fatal: muster rename must run inside tmux'
    muster_window_slug $o_slug
    muster_window_slug $o_to
    [[ $o_slug != $o_to ]] || abend 'fatal: old and new window slugs are identical'

    typeset old_pane=$HOME/pane/$o_slug new_pane=$HOME/pane/$o_to
    [[ -d $old_pane && ! -L $old_pane ]] ||
        abend 'fatal: no ordinary window directory at %s' "$old_pane"
    ! muster_rename_exists $new_pane ||
        abend 'fatal: rename destination already exists: %s' "$new_pane"
    typeset muster_rename_old_pane=${old_pane:A}
    typeset muster_rename_new_pane=${new_pane:A}

    muster_messages_configure
    [[ -z ${MUSTER_MESSAGES_SSH:-} ]] ||
        abend 'fatal: window rename does not support remote message storage'

    muster_state_root
    typeset muster_rename_state=$REPLY
    typeset lock=$muster_rename_state/rename.lock

    typeset -a muster_rename_sources=() muster_rename_destinations=()
    typeset -a muster_rename_guard_destinations=()
    typeset -a muster_rename_backup_files=() muster_rename_backups=()
    typeset -a muster_rename_puzzle_panes=() muster_rename_windows=()
    typeset -a muster_rename_changed_panes=() muster_rename_changed_windows=()
    typeset -a muster_rename_thread_ids=() muster_rename_seats=()
    integer muster_rename_codex_server=0
    integer muster_rename_rollback_failed=0
    integer muster_rename_lock_acquired=0
    typeset muster_rename_claude_config= muster_rename_codex_config=
    typeset muster_rename_grok_trust= muster_rename_transaction=
    typeset result=1
    {
        typeset root
        for root in codex claude fable grok omp; do
            muster_rename_add_move \
                $muster_rename_state/$root/$o_slug \
                $muster_rename_state/$root/$o_to
        done

        typeset messages=$muster_rename_state/messages entry name
        for entry in $messages/*(N); do
            name=${entry:t}
            [[ $name != $o_to && $name != $o_to-* ]] ||
                abend 'fatal: destination message address already exists: %s' "$name"
        done
        for entry in $messages/*(N); do
            name=${entry:t}
            if [[ $name == $o_slug || $name == $o_slug-* ]]; then
                [[ -d $entry && ! -L $entry ]] ||
                    abend 'fatal: message address is not an ordinary directory: %s' "$entry"
                muster_rename_add_move $entry $messages/${o_to}${name#$o_slug}
            fi
        done

        typeset config seat sid seat_dir
        typeset seats_dir=$muster_rename_state/codex/$o_slug/seats
        [[ ! -L $seats_dir ]] ||
            abend 'fatal: Codex seats directory must not be a symbolic link: %s' "$seats_dir"
        for seat_dir in $seats_dir/*(N); do
            [[ -d $seat_dir && ! -L $seat_dir ]] ||
                abend 'fatal: Codex seat must be an ordinary directory: %s' "$seat_dir"
            [[ -f $seat_dir/config.json && ! -L $seat_dir/config.json ]] ||
                abend 'fatal: Codex seat has no ordinary configuration file: %s' "$seat_dir"
            [[ -f $seat_dir/sid.json && ! -L $seat_dir/sid.json ]] ||
                abend 'fatal: Codex seat has no ordinary session ID file: %s' "$seat_dir"
        done
        for config in $muster_rename_state/codex/$o_slug/seats/*/config.json(N); do
            [[ ! -L $config ]] ||
                abend 'fatal: Codex seat configuration must not be a symbolic link: %s' "$config"
            [[ -f $config ]] ||
                abend 'fatal: Codex seat configuration is not a file: %s' "$config"
            seat=${config:h:t}
            muster_window_slug $seat
            [[ $(jq -er '.address' $config 2>/dev/null) == ${o_slug}-${seat} ]] ||
                abend 'fatal: invalid Codex seat address in %s' "$config"
            muster_rename_seats+=( $seat )
        done
        for config in \
            $muster_rename_state/codex/$o_slug/sid.json(N) \
            $muster_rename_state/codex/$o_slug/seats/*/sid.json(N)
        do
            [[ -f $config && ! -L $config ]] ||
                abend 'fatal: Codex session ID is not an ordinary file: %s' "$config"
            sid=$(jq -er 'strings | select(length > 0)' $config 2>/dev/null) ||
                abend 'fatal: invalid Codex session ID in %s' "$config"
            muster_rename_thread_ids+=( $sid )
        done

        for seat in $muster_rename_seats; do
            muster_rename_require_session_absent muster-codex ${o_slug}-${seat} source
            muster_rename_require_session_absent muster-codex ${o_to}-${seat} destination
        done
        muster_rename_require_session_absent muster-claude ${o_slug}-claude source
        muster_rename_require_session_absent muster-claude ${o_to}-claude destination
        muster_rename_require_session_absent muster-claude ${o_slug}-fable source
        muster_rename_require_session_absent muster-claude ${o_to}-fable destination
        muster_rename_require_session_absent muster-grok ${o_slug}-grok source
        muster_rename_require_session_absent muster-grok ${o_to}-grok destination
        muster_rename_require_session_absent muster-omp $o_slug source
        muster_rename_require_session_absent muster-omp $o_to destination
        muster_rename_require_session_absent muster-collaboration $o_slug source
        muster_rename_require_session_absent muster-collaboration $o_to destination

        typeset request request_thread
        for request in $muster_rename_state/codex/nudges/{requests,processing}/*(N.); do
            request_thread=$(jq -r '.thread // empty' $request 2>/dev/null)
            (( ${muster_rename_thread_ids[(Ie)$request_thread]} == 0 )) ||
                abend 'fatal: Codex nudge is still queued for %s' "$o_slug"
        done
        muster_rename_require_idle_threads ||
            abend 'fatal: every Codex thread must be idle before renaming'

        typeset old_url=http://localhost:6502/mcp/$o_slug
        typeset pane_codex=$old_pane/.codex/config.toml
        typeset pane_mcp=$old_pane/.mcp.json
        [[ ! -L $pane_codex ]] ||
            abend 'fatal: pane Codex configuration must not be a symbolic link: %s' "$pane_codex"
        if [[ -f $pane_codex ]] && grep -Fq '[mcp_servers.o]' $pane_codex; then
            grep -Fq -- "${old_url}\"" $pane_codex ||
                abend 'fatal: pane Codex MCP route does not match %s' "$o_slug"
        fi
        [[ ! -L $pane_mcp ]] ||
            abend 'fatal: pane MCP configuration must not be a symbolic link: %s' "$pane_mcp"
        if [[ -f $pane_mcp ]]; then
            jq -e . $pane_mcp >/dev/null 2>&1 ||
                abend 'fatal: invalid pane MCP configuration: %s' "$pane_mcp"
            if jq -e '.mcpServers.o' $pane_mcp >/dev/null 2>&1; then
                [[ $(jq -er '.mcpServers.o.url' $pane_mcp 2>/dev/null) == $old_url ]] ||
                    abend 'fatal: pane Claude MCP route does not match %s' "$o_slug"
            fi
        fi

        typeset wicket_old=$HOME/.local/state/wicket/$o_slug job stem
        [[ ! -L $wicket_old/sandbox.conf ]] ||
            abend 'fatal: Wicket configuration must not be a symbolic link: %s' \
                "$wicket_old/sandbox.conf"
        for job in $wicket_old/jobs/*/*.job(N.); do
            stem=${job:t:r}
            [[ $stem =~ '\.-?[0-9]+$' ]] ||
                abend 'fatal: Wicket job may still be running for %s: %s' "$o_slug" "$job"
        done
        muster_rename_add_move $wicket_old $HOME/.local/state/wicket/$o_to

        typeset claude_home=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
        typeset old_encoded=${muster_rename_old_pane//\//-}
        typeset new_encoded=${muster_rename_new_pane//\//-}
        muster_rename_add_move \
            $claude_home/projects/$old_encoded \
            $claude_home/projects/$new_encoded
        muster_rename_claude_config=${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json
        [[ ! -f ${CLAUDE_CONFIG_DIR:-$HOME}/.config.json ]] ||
            muster_rename_claude_config=${CLAUDE_CONFIG_DIR:-$HOME}/.config.json
        [[ ! -L $muster_rename_claude_config ]] ||
            abend 'fatal: Claude configuration must not be a symbolic link: %s' \
                "$muster_rename_claude_config"
        [[ ! -f $muster_rename_claude_config ]] ||
            jq -e . $muster_rename_claude_config >/dev/null 2>&1 ||
            abend 'fatal: invalid Claude configuration: %s' "$muster_rename_claude_config"
        if [[ -f $muster_rename_claude_config ]] &&
            jq -e --arg new "$muster_rename_new_pane" \
                '.projects | objects | has($new)' \
                $muster_rename_claude_config >/dev/null 2>&1
        then
            abend 'fatal: Claude already has project state for %s' "$muster_rename_new_pane"
        fi

        muster_rename_codex_config=${CODEX_HOME:-$HOME/.codex}/config.toml
        [[ ! -L $muster_rename_codex_config ]] ||
            abend 'fatal: Codex configuration must not be a symbolic link: %s' \
                "$muster_rename_codex_config"
        if [[ -f $muster_rename_codex_config ]] &&
            grep -Fq -- \
                "projects.\"${muster_rename_new_pane}\"" \
                $muster_rename_codex_config
        then
            abend 'fatal: Codex already has project state for %s' "$muster_rename_new_pane"
        fi

        typeset old_grok=$(jq -rn --arg path "$muster_rename_old_pane" '$path | @uri')
        typeset new_grok=$(jq -rn --arg path "$muster_rename_new_pane" '$path | @uri')
        typeset grok_home=${GROK_HOME:-$HOME/.grok}
        typeset grok_active=$grok_home/active_sessions.json
        if [[ -f $grok_active ]]; then
            jq -e . $grok_active >/dev/null 2>&1 ||
                abend 'fatal: invalid Grok active-session registry: %s' "$grok_active"
            ! jq -e --arg cwd "$muster_rename_old_pane" \
                'any(.[]; .cwd == $cwd)' $grok_active >/dev/null 2>&1 ||
                abend 'fatal: Grok is still active for %s' "$o_slug"
        fi
        muster_rename_grok_trust=$grok_home/trusted_folders.toml
        [[ ! -L $muster_rename_grok_trust ]] ||
            abend 'fatal: Grok trust configuration must not be a symbolic link: %s' \
                "$muster_rename_grok_trust"
        if [[ -f $muster_rename_grok_trust ]] &&
            grep -Fq -- \
                "[folders.\"${muster_rename_new_pane}\"]" \
                $muster_rename_grok_trust
        then
            abend 'fatal: Grok already trusts the destination: %s' "$muster_rename_new_pane"
        fi
        muster_rename_add_move \
            $grok_home/sessions/$old_grok \
            $grok_home/sessions/$new_grok
        muster_rename_add_move $old_pane $new_pane

        typeset line pane command pane_tags pane_commands window_list window_panes
        pane_tags=$(tmux list-panes -a -F '#{pane_id}|#{@puzzle-slug}') ||
            abend 'fatal: cannot inspect tmux panes'
        pane_commands=$(tmux list-panes -a -F '#{pane_current_command}') ||
            abend 'fatal: cannot inspect tmux pane commands'
        window_list=$(tmux list-windows -a -F '#{session_name}|#{window_id}|#{window_name}') ||
            abend 'fatal: cannot inspect tmux windows'
        for line in ${(f)pane_tags}; do
            pane=${line%%|*}
            if [[ ${line#*|} == $o_to ]]; then
                abend 'fatal: Puzzle already has a pane for %s' "$o_to"
            elif [[ ${line#*|} == $o_slug ]]; then
                command=$(tmux display-message -p -t $pane '#{pane_current_command}') ||
                    abend 'fatal: cannot inspect Puzzle pane: %s' "$pane"
                [[ $command != codex ]] ||
                    abend 'fatal: stop the Codex TUI for %s before renaming' "$o_slug"
                muster_rename_puzzle_panes+=( $pane )
            fi
        done
        for line in ${(f)pane_commands}; do
            [[ $line != puzzle ]] || abend 'fatal: close Puzzle before renaming a window'
        done

        typeset session window_id window_name
        for line in ${(f)window_list}; do
            session=${line%%|*}
            line=${line#*|}
            window_id=${line%%|*}
            window_name=${line#*|}
            if [[ $session != puzzle-parking && $window_name == $o_to ]]; then
                abend 'fatal: tmux already has a window named %s' "$o_to"
            elif [[ $session != puzzle-parking && $window_name == $o_slug ]]; then
                muster_rename_windows+=( $window_id )
            fi
        done
        for window_id in $muster_rename_windows; do
            window_panes=$(tmux list-panes -t $window_id -F '#{pane_current_command}') ||
                abend 'fatal: cannot inspect tmux window: %s' "$window_id"
            for command in ${(f)window_panes}; do
                case $command in
                (codex|claude|grok|omp)
                    abend 'fatal: stop the %s process in tmux window %s before renaming' \
                        "$command" "$window_id"
                    ;;
                esac
            done
        done

        if (( o_dry_run )); then
            print -r -- "rename $o_slug -> $o_to"
            integer index
            if (( ${#muster_rename_sources} )); then
                for index in {1..${#muster_rename_sources}}; do
                    print -r -- \
                        "move $muster_rename_sources[$index] -> $muster_rename_destinations[$index]"
                done
            fi
            for pane in $muster_rename_puzzle_panes; do
                print -r -- "retag Puzzle pane $pane -> $o_to"
            done
            for window_id in $muster_rename_windows; do
                print -r -- "rename tmux window $window_id -> $o_to"
            done
            result=0
            return
        fi

        mkdir -p $muster_rename_state ||
            abend 'fatal: cannot create Muster state directory'
        mkdir $lock 2>/dev/null ||
            abend 'fatal: another window rename is already in progress'
        muster_rename_lock_acquired=1
        muster_rename_revalidate_plan || {
            rmdir $lock 2>/dev/null
            muster_rename_lock_acquired=0
            abend 'fatal: rename plan changed during preflight'
        }
        muster_rename_transaction=$(mktemp -d $muster_rename_state/.rename.XXXXXX) || {
            rmdir $lock 2>/dev/null
            muster_rename_lock_acquired=0
            abend 'fatal: cannot create rename transaction'
        }
        if muster_rename_apply; then
            if (( ! muster_rename_codex_server )) ||
                muster_rename_reconfigure_threads $o_to $muster_rename_new_pane
            then
                result=0
                print -r -- "renamed $o_slug to $o_to"
            else
                print -u2 -- \
                    "fatal: renamed $o_slug to $o_to, but could not reconfigure every Codex thread"
            fi
        else
            if (( muster_rename_rollback_failed )); then
                print -u2 -- \
                    "fatal: unable to rename $o_slug to $o_to; recovery state remains at $muster_rename_transaction"
            else
                print -u2 -- \
                    "fatal: unable to rename $o_slug to $o_to; completed moves were rolled back"
            fi
        fi
    } always {
        if (( ! muster_rename_rollback_failed )); then
            [[ -z ${muster_rename_transaction:-} ]] || rm -rf $muster_rename_transaction
            (( ! muster_rename_lock_acquired )) || rmdir $lock 2>/dev/null
        fi
    }
    return $result
}
