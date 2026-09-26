function :help:windows {
    help=$(<${functions_source[:help:windows]:A:h}/help.md)
}

function :args:windows {
    typeset parsed
    parsed=$(args -bx h,help ,json -- "$@") || exit $?
    eval "$parsed"
}

function muster_windows_require_directory {
    typeset registration_path=$1 description=$2
    [[ -e $registration_path || -L $registration_path ]] \
        || abend 'fatal: missing %s: %s' "$description" "$registration_path"
    [[ -d $registration_path && ! -L $registration_path \
        && -r $registration_path && -x $registration_path ]] \
        || abend 'fatal: %s must be an ordinary readable directory: %s' \
            "$description" "$registration_path"
}

function muster_windows_require_state_root {
    typeset state_root=$1
    [[ -d $state_root && -r $state_root && -x $state_root ]] \
        || abend 'fatal: Muster state root must resolve to a readable directory: %s' \
            "$state_root"
}

function muster_windows_require_safe_missing_state_root {
    typeset state_root=$1 ancestor=$1 parent

    while [[ ! -e $ancestor && ! -L $ancestor ]]; do
        parent=${ancestor:h}
        [[ $parent != $ancestor ]] \
            || abend 'fatal: cannot resolve configured Muster state root: %s' \
                "$state_root"
        ancestor=$parent
    done

    [[ -d $ancestor && -x $ancestor ]] \
        || abend 'fatal: configured Muster state root %s is hidden by an unsearchable ancestor: %s' \
            "$state_root" "$ancestor"
}

function muster_windows_require_file {
    typeset registration_path=$1 description=$2
    [[ -e $registration_path || -L $registration_path ]] \
        || abend 'fatal: missing %s: %s' "$description" "$registration_path"
    [[ -f $registration_path && ! -L $registration_path \
        && -r $registration_path ]] \
        || abend 'fatal: %s must be an ordinary readable file: %s' \
            "$description" "$registration_path"
}

function muster_windows_validate_slug {
    typeset value=$1 registration_path=$2 description=$3
    ( muster_window_slug "$value" ) 2>/dev/null \
        || abend 'fatal: invalid %s in %s: %s' \
            "$description" "$registration_path" \
            "${value:-(empty)}"
}

function muster_windows_validate_address {
    typeset value=$1 registration_path=$2
    ( muster_address "$value" ) 2>/dev/null \
        || abend 'fatal: invalid address in %s: %s' "$registration_path" \
            "${value:-(empty)}"
}

function muster_windows_prepare_window_directory {
    typeset registration_path=$1 description=$2 window=${1:t}

    if ( muster_window_slug "$window" ) 2>/dev/null; then
        [[ ! -L $registration_path ]] \
            || abend 'fatal: %s must not be a symbolic link: %s' \
                "$description" "$registration_path"
        [[ -d $registration_path ]] || return 1
        muster_windows_require_directory "$registration_path" "$description"
    else
        # Invalidly named ordinary directories remain unrelated until they
        # contain a registration marker. A symlink to a directory is never an
        # acceptable registration path, regardless of its name.
        [[ -d $registration_path ]] || return 1
        [[ ! -L $registration_path ]] \
            || abend 'fatal: %s must not be a symbolic link: %s' \
                "$description" "$registration_path"
    fi
    REPLY=$window
}

function muster_windows_codex_thread_id {
    typeset registration_path=$1
    muster_windows_require_file "$registration_path" 'Codex session ID'
    REPLY=$(jq -ers '
        if length == 1 and
            (.[0] |
                type == "string" and
                length > 0 and
                (contains("\n") | not) and
                (contains("\u0000") | not))
        then .[0]
        else error("expected one shell-safe nonempty string")
        end
    ' "$registration_path" 2>/dev/null) \
        || abend 'fatal: invalid Codex session ID in %s' "$registration_path"
}

function muster_windows_uuid_token {
    typeset registration_path=$1 description=$2 value
    muster_windows_require_file "$registration_path" "$description"
    value=$(<$registration_path)
    [[ -n $value ]] \
        || abend 'fatal: empty %s in %s' "$description" "$registration_path"
    jq -en --arg id "$value" '
        $id | test("^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$")
    ' >/dev/null \
        || abend 'fatal: invalid %s in %s' "$description" "$registration_path"
    REPLY=$value
}

function muster_windows_add_row {
    typeset window=$1 address=$2 harness=$3 registration_path=$4
    typeset thread_id=${5:-} row
    muster_windows_validate_address "$address" "$registration_path"
    if (( ${+muster_windows_seen[$address]} )); then
        abend 'fatal: duplicate participant address in %s (already registered by %s): %s' \
            "$registration_path" "${muster_windows_seen[$address]}" "$address"
    fi
    muster_windows_seen[$address]=$registration_path

    if [[ $harness == codex ]]; then
        row=$(jq -cn \
            --arg window "$window" \
            --arg address "$address" \
            --arg harness "$harness" \
            --arg thread_id "$thread_id" \
            '{window: $window, address: $address, harness: $harness, thread_id: $thread_id}') \
            || abend 'fatal: cannot encode registration from %s' "$registration_path"
    else
        row=$(jq -cn \
            --arg window "$window" \
            --arg address "$address" \
            --arg harness "$harness" \
            '{window: $window, address: $address, harness: $harness}') \
            || abend 'fatal: cannot encode registration from %s' "$registration_path"
    fi
    muster_windows_rows+=( "$row" )
}

function muster_windows_inventory_codex {
    typeset namespace=$1 window_dir window sid_file seats_dir seat_dir seat
    typeset config config_address config_model config_effort thread_id
    typeset config_value

    for window_dir in $namespace/*(N); do
        muster_windows_prepare_window_directory \
            "$window_dir" 'Codex registration directory' || continue
        window=$REPLY

        sid_file=$window_dir/sid.json
        seats_dir=$window_dir/seats
        if [[ ! -e $sid_file && ! -L $sid_file \
            && ! -e $seats_dir && ! -L $seats_dir ]]
        then
            continue
        fi

        muster_windows_require_directory "$window_dir" 'Codex registration directory'
        muster_windows_validate_slug "$window" "$window_dir" 'Codex window name'

        if [[ -e $sid_file || -L $sid_file ]]; then
            muster_windows_codex_thread_id "$sid_file"
            thread_id=$REPLY
            muster_windows_add_row "$window" "$window" codex "$sid_file" "$thread_id"
        fi

        if [[ -e $seats_dir || -L $seats_dir ]]; then
            muster_windows_require_directory "$seats_dir" 'Codex seats directory'
            for seat_dir in $seats_dir/*(N); do
                [[ -d $seat_dir && ! -L $seat_dir ]] \
                    || abend 'fatal: Codex seat must be an ordinary directory: %s' \
                        "$seat_dir"
                [[ -r $seat_dir && -x $seat_dir ]] \
                    || abend 'fatal: Codex seat must be a readable directory: %s' \
                        "$seat_dir"
                seat=${seat_dir:t}
                muster_windows_validate_slug "$seat" "$seat_dir" 'Codex seat name'
                [[ $seat != codex ]] \
                    || abend 'fatal: reserved Codex seat name in %s: %s' \
                        "$seat_dir" "$seat"

                config=$seat_dir/config.json
                sid_file=$seat_dir/sid.json
                muster_windows_require_file "$config" 'Codex seat configuration'
                muster_windows_require_file "$sid_file" 'Codex seat session ID'

                config_value=$(jq -ce --slurp '
                    def shell_string:
                        type == "string" and
                        length > 0 and
                        (contains("\n") | not) and
                        (contains("\u0000") | not);
                    if length == 1 and
                        (.[0] |
                            type == "object" and
                            (.address | shell_string) and
                            (.model | shell_string) and
                            (.effort | shell_string))
                    then .[0]
                    else error("expected one complete seat configuration")
                    end
                ' "$config" 2>/dev/null) \
                    || abend 'fatal: invalid Codex seat configuration in %s' "$config"
                config_address=$(jq -er '.address' <<< "$config_value") \
                    || abend 'fatal: invalid Codex seat address in %s' "$config"
                # The model remains an opaque nonempty string, as it is in the
                # existing seat reader.
                config_model=$(jq -er '.model' <<< "$config_value") \
                    || abend 'fatal: invalid Codex seat model in %s' "$config"
                config_effort=$(jq -er '.effort' <<< "$config_value") \
                    || abend 'fatal: invalid Codex seat effort in %s' "$config"
                [[ $config_address == ${window}-${seat} ]] \
                    || abend 'fatal: Codex seat address does not match its path in %s: %s' \
                        "$config" "$config_address"
                muster_windows_validate_address "$config_address" "$config"
                case $config_effort in
                    (low|medium|high|xhigh) ;;
                    (*)
                        abend 'fatal: invalid Codex effort in %s: %s' \
                            "$config" "$config_effort"
                        ;;
                esac

                muster_windows_codex_thread_id "$sid_file"
                thread_id=$REPLY
                muster_windows_add_row \
                    "$window" "$config_address" codex "$sid_file" "$thread_id"
            done
        fi
    done
}

function muster_windows_inventory_uuid_harness {
    typeset namespace=$1 harness=$2 suffix=$3 description=$4
    typeset window_dir window sid_file

    for window_dir in $namespace/*(N); do
        muster_windows_prepare_window_directory \
            "$window_dir" "$description registration directory" || continue
        window=$REPLY
        sid_file=$window_dir/sid
        [[ -e $sid_file || -L $sid_file ]] || continue

        muster_windows_require_directory "$window_dir" \
            "$description registration directory"
        muster_windows_validate_slug "$window" "$window_dir" \
            "$description window name"
        muster_windows_uuid_token "$sid_file" "$description session ID"
        muster_windows_add_row \
            "$window" "${window}-${suffix}" "$harness" "$sid_file"
    done
}

function muster_windows_inventory_omp {
    typeset namespace=$1 window_dir window active_file topic topics_dir
    typeset topic_dir model_file model

    for window_dir in $namespace/*(N); do
        muster_windows_prepare_window_directory \
            "$window_dir" 'OMP registration directory' || continue
        window=$REPLY
        active_file=$window_dir/active
        [[ -e $active_file || -L $active_file ]] || continue

        muster_windows_require_directory "$window_dir" 'OMP registration directory'
        muster_windows_validate_slug "$window" "$window_dir" 'OMP window name'
        muster_windows_require_file "$active_file" 'OMP active topic'
        topic=$(<$active_file)
        [[ -n $topic ]] || abend 'fatal: empty OMP active topic in %s' "$active_file"
        muster_windows_validate_slug "$topic" "$active_file" 'OMP active topic'

        topics_dir=$window_dir/topics
        topic_dir=$topics_dir/$topic
        model_file=$topic_dir/model
        muster_windows_require_directory "$topics_dir" 'OMP topics directory'
        muster_windows_require_directory "$topic_dir" 'OMP active topic directory'
        muster_windows_require_file "$model_file" 'OMP active topic model'
        model=$(<$model_file)
        case $model in
            (sol|opus|fable) ;;
            (*) abend 'fatal: invalid OMP model in %s: %s' \
                    "$model_file" "${model:-(empty)}" ;;
        esac

        muster_windows_add_row "$window" "${window}-omp" omp "$active_file"
    done
}

function :execute:windows {
    emulate -L zsh
    setopt extendedglob

    (( o_json )) \
        || abend 'fatal: usage: muster windows --json'
    [[ $# -eq 0 ]] \
        || abend 'fatal: usage: muster windows --json'

    muster_state_root
    typeset state_root=$REPLY namespace harness
    typeset -a muster_windows_rows=()
    typeset -A muster_windows_seen=()

    while [[ $state_root != / && $state_root == */ ]]; do
        state_root=${state_root%/}
    done

    if [[ ! -e $state_root && ! -L $state_root ]]; then
        muster_windows_require_safe_missing_state_root "$state_root"
        print -r -- '[]'
        return
    fi
    muster_windows_require_state_root "$state_root"

    namespace=$state_root/codex
    if [[ -e $namespace || -L $namespace ]]; then
        muster_windows_require_directory "$namespace" 'Codex state namespace'
        muster_windows_inventory_codex "$namespace"
    fi

    for harness in claude fable grok; do
        namespace=$state_root/$harness
        if [[ -e $namespace || -L $namespace ]]; then
            muster_windows_require_directory "$namespace" \
                "${(C)harness} state namespace"
            muster_windows_inventory_uuid_harness \
                "$namespace" "$harness" "$harness" "${(C)harness}"
        fi
    done

    namespace=$state_root/omp
    if [[ -e $namespace || -L $namespace ]]; then
        muster_windows_require_directory "$namespace" 'OMP state namespace'
        muster_windows_inventory_omp "$namespace"
    fi

    if (( ${#muster_windows_rows} )); then
        printf '%s\n' "${(@)muster_windows_rows}" |
            jq -sc 'sort_by(.window, .address, .harness)'
    else
        print -r -- '[]'
    fi
}
