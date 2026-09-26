#!/usr/bin/env zsh

emulate -L zsh
setopt extendedglob

typeset root=${ZSH_ARGZERO:A:h:h}
typeset zshctl=${ZSHCTL:-$(command -v zshctl)}
[[ -n $zshctl ]] \
    || { print -r -u 2 -- 'windows: zshctl not found; set ZSHCTL'; exit 1; }

typeset work
work=$(mktemp -d ${TMPDIR:-/tmp}/muster-windows.XXXXXX) || exit 1
trap "rm -rf ${(q)work}" EXIT HUP INT TERM

typeset home=$work/home fake_bin=$work/bin
typeset forbidden_log=$work/forbidden.log
typeset stdout_file=$work/stdout stderr_file=$work/stderr
mkdir -p $home $fake_bin
: > $forbidden_log

cat > $fake_bin/forbidden <<'EOF'
#!/bin/sh
printf '%s\n' "$0 $*" >> "$MUSTER_FORBIDDEN_LOG"
exit 97
EOF
chmod +x $fake_bin/forbidden
typeset forbidden
for forbidden in \
    tmux ps pgrep pkill lsof codex claude fable grok omp uuidgen fswatch \
    codex-nudge codex-nudge-relay
do
    ln -s forbidden $fake_bin/$forbidden
done
export MUSTER_FORBIDDEN_LOG=$forbidden_log

integer failures=0 run_code=0
typeset run_out= run_err=

function run_windows {
    typeset state=$1
    shift
    : > $stdout_file
    : > $stderr_file
    HOME=$home \
        MUSTER_STATE_HOME=$state \
        PATH=$fake_bin:$PATH \
        ZSHCTL_HELP_TEXT=1 \
        $zshctl $root/bin/muster windows "$@" \
        > $stdout_file 2> $stderr_file
    run_code=$?
    run_out=$(<$stdout_file)
    run_err=$(<$stderr_file)
}

function pass {
    print -r -- "ok: $1"
}

function fail {
    print -r -u 2 -- "FAIL: $1"
    shift
    (( $# == 0 )) || print -r -u 2 -- "  $*"
    (( failures++ ))
}

function assert_code {
    typeset name=$1
    integer expected=$2 actual=$3
    if (( expected == actual )); then
        pass "$name"
    else
        fail "$name" "expected exit $expected, got $actual"
    fi
}

function assert_failure {
    typeset name=$1 state=$2 expected_path=$3
    run_windows $state --json
    if (( run_code != 0 )); then
        pass "$name exits nonzero"
    else
        fail "$name exits nonzero" 'command succeeded'
    fi
    if [[ ! -s $stdout_file ]]; then
        pass "$name emits no stdout"
    else
        fail "$name emits no stdout" "got: $run_out"
    fi
    if [[ $run_err == *$expected_path* ]]; then
        pass "$name names its path"
    else
        fail "$name names its path" "expected $expected_path in: $run_err"
    fi
}

function tree_snapshot {
    typeset tree=$1
    {
        find $tree -exec stat -f '%Sp %m %z %N' {} \;
        find $tree -type f -exec shasum {} \;
        find $tree -type l -exec readlink {} \;
    } | LC_ALL=C sort
}

function write_seat_config {
    typeset config_file=$1 address=$2 model=${3:-gpt-test} effort=${4:-high}
    jq -n \
        --arg address $address \
        --arg model $model \
        --arg effort $effort \
        '{address: $address, model: $model, effort: $effort}' > $config_file
}

typeset state=$work/state
mkdir -p \
    $state/codex/alpha/seats/sol \
    $state/codex/alpha/seats/.staged \
    $state/codex/beta \
    $state/codex/nudges/requests \
    $state/claude/zeta \
    $state/fable/alpha \
    $state/grok/beta \
    $state/omp/alpha/topics/selected \
    $state/omp/alpha/topics/unselected \
    $state/omp/legacy
print -r -- '"thread-shared"' > $state/codex/alpha/seats/sol/sid.json
write_seat_config $state/codex/alpha/seats/sol/config.json alpha-sol
print -r -- 'not a registration' > $state/codex/alpha/seats/.staged/config.json
print -r -- '"thread-shared"' > $state/codex/beta/sid.json
print -r -- 'infrastructure' > $state/codex/app-server.log
print -r -- 'not a registration' > $work/socket-target
ln -s $work/socket-target $state/codex/app-server.sock
print -r -- 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' > $state/claude/zeta/sid
print -r -- 'infrastructure' > $state/claude/hooks.log
print -r -- 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' > $state/fable/alpha/sid
print -r -- 'cccccccc-cccc-4ccc-8ccc-cccccccccccc' > $state/grok/beta/sid
print -r -- selected > $state/omp/alpha/active
print -r -- sol > $state/omp/alpha/topics/selected/model
print -r -- unsupported > $state/omp/alpha/topics/unselected/model
print -r -- '{"legacy":true}' > $state/omp/legacy/sid.jsonl
print -r -- 'legacy-token' > $state/omp/legacy/sid

typeset before=$(tree_snapshot $state)
run_windows $state --json
assert_code 'full inventory exits zero' 0 $run_code
if jq -e '
    . == [
        {window:"alpha", address:"alpha-fable", harness:"fable"},
        {window:"alpha", address:"alpha-omp", harness:"omp"},
        {window:"alpha", address:"alpha-sol", harness:"codex", thread_id:"thread-shared"},
        {window:"beta", address:"beta", harness:"codex", thread_id:"thread-shared"},
        {window:"beta", address:"beta-grok", harness:"grok"},
        {window:"zeta", address:"zeta-claude", harness:"claude"}
    ]
' $stdout_file >/dev/null; then
    pass 'full inventory is complete and deterministically sorted'
else
    fail 'full inventory is complete and deterministically sorted' "$run_out"
fi
if jq -e '
    all(.[];
        if .harness == "codex"
        then (keys == ["address", "harness", "thread_id", "window"] and
              all(.[]; type == "string"))
        else (keys == ["address", "harness", "window"] and
              all(.[]; type == "string"))
        end)
' $stdout_file >/dev/null; then
    pass 'rows contain exactly the contracted string fields'
else
    fail 'rows contain exactly the contracted string fields'
fi
typeset last_byte=$(tail -c 1 $stdout_file | od -An -t x1)
last_byte=${last_byte//[[:space:]]/}
if [[ $last_byte == 0a ]]; then
    pass 'JSON output is newline terminated'
else
    fail 'JSON output is newline terminated' "last byte: $last_byte"
fi
typeset first_output=$run_out
run_windows $state --json
if [[ $run_code -eq 0 && $run_out == $first_output ]]; then
    pass 'sorting is stable across runs'
else
    fail 'sorting is stable across runs'
fi
typeset after=$(tree_snapshot $state)
if [[ $before == $after ]]; then
    pass 'inventory leaves the fixture tree unchanged'
else
    fail 'inventory leaves the fixture tree unchanged'
fi

typeset empty_root=$work/empty missing_root=$work/missing
mkdir -p $empty_root
run_windows $missing_root --json
if [[ $run_code -eq 0 && $run_out == '[]' && ! -e $missing_root ]]; then
    pass 'missing state root is an empty inventory and remains absent'
else
    fail 'missing state root is an empty inventory and remains absent' \
        "exit=$run_code output=$run_out"
fi
run_windows $empty_root --json
if [[ $run_code -eq 0 && $run_out == '[]' ]]; then
    pass 'missing harness namespaces are an empty inventory'
else
    fail 'missing harness namespaces are an empty inventory' \
        "exit=$run_code output=$run_out"
fi

typeset linked_root_target=$work/linked-root-target
typeset linked_root=$work/linked-root
mkdir -p $linked_root_target/codex/linked
print -r -- '"linked-root-thread"' > $linked_root_target/codex/linked/sid.json
ln -s $linked_root_target $linked_root
run_windows $linked_root --json
if (( run_code == 0 )) && jq -e '
    . == [{window:"linked", address:"linked", harness:"codex", thread_id:"linked-root-thread"}]
' $stdout_file >/dev/null; then
    pass 'configured state root may resolve through a symbolic link'
else
    fail 'configured state root may resolve through a symbolic link' \
        "exit=$run_code output=$run_out stderr=$run_err"
fi

run_windows $linked_root/ --json
if (( run_code == 0 )) && jq -e '
    . == [{window:"linked", address:"linked", harness:"codex", thread_id:"linked-root-thread"}]
' $stdout_file >/dev/null; then
    pass 'configured state root symbolic link accepts a trailing separator'
else
    fail 'configured state root symbolic link accepts a trailing separator' \
        "exit=$run_code output=$run_out stderr=$run_err"
fi

typeset dangling_root=$work/dangling-root
ln -s $work/missing-root-target $dangling_root
assert_failure 'dangling configured-root symbolic link rejects a trailing separator' \
    $dangling_root/ $dangling_root

typeset hidden_root=$work/hidden-root
mkdir -p $hidden_root/parent/state/codex/window
print -r -- '"hidden-thread"' \
    > $hidden_root/parent/state/codex/window/sid.json
chmod 000 $hidden_root/parent
assert_failure 'state root beneath an unsearchable ancestor' \
    $hidden_root/parent/state $hidden_root/parent
chmod 700 $hidden_root/parent

run_windows $state
if (( run_code != 0 )) && [[ ! -s $stdout_file && $run_err == *'muster windows --json'* ]]; then
    pass 'bare windows command requires --json without stdout'
else
    fail 'bare windows command requires --json without stdout' \
        "exit=$run_code stdout=$run_out stderr=$run_err"
fi
run_windows $state --json extra
if (( run_code != 0 )) && [[ ! -s $stdout_file ]]; then
    pass 'positionals are rejected without stdout'
else
    fail 'positionals are rejected without stdout' "exit=$run_code stdout=$run_out"
fi
run_windows $state --bogus
if (( run_code != 0 )) && [[ ! -s $stdout_file ]]; then
    pass 'unknown flags are rejected without stdout'
else
    fail 'unknown flags are rejected without stdout' "exit=$run_code stdout=$run_out"
fi
run_windows $state -j
if (( run_code != 0 )) && [[ ! -s $stdout_file ]]; then
    pass 'the JSON surface requires the named --json flag'
else
    fail 'the JSON surface requires the named --json flag' \
        "exit=$run_code stdout=$run_out"
fi
run_windows $state --help
if (( run_code == 0 )) \
    && [[ $run_out == *'persisted participant registrations'* ]] \
    && [[ $run_out == *'includes detached participants'* ]] \
    && [[ $run_out == *'makes no claim'* ]]
then
    pass 'help describes persisted registrations without a liveness claim'
else
    fail 'help describes persisted registrations without a liveness claim' "$run_out"
fi

typeset rename_state=$work/rename
mkdir -p $rename_state/codex/old_name
print -r -- '"rename-thread"' > $rename_state/codex/old_name/sid.json
run_windows $rename_state --json
typeset old_row=$(jq -c '.[0]' $stdout_file)
mv $rename_state/codex/old_name $rename_state/codex/new_name
run_windows $rename_state --json
if jq -e '
    . == [{window:"new_name", address:"new_name", harness:"codex", thread_id:"rename-thread"}]
' $stdout_file >/dev/null \
    && [[ $old_row == \
        '{"window":"old_name","address":"old_name","harness":"codex","thread_id":"rename-thread"}' ]]
then
    pass 'rename changes the window and address while preserving thread identity'
else
    fail 'rename changes the window and address while preserving thread identity' \
        "before=$old_row after=$run_out"
fi

typeset bad=$work/bad-marker
mkdir -p $bad/codex/window
print -r -- '{bad json' > $bad/codex/window/sid.json
assert_failure 'malformed Codex marker' $bad $bad/codex/window/sid.json

bad=$work/empty-codex-marker
mkdir -p $bad/codex/window
print -r -- '""' > $bad/codex/window/sid.json
assert_failure 'empty Codex marker' $bad $bad/codex/window/sid.json

bad=$work/newline-codex-marker
mkdir -p $bad/codex/window
print -r -- '"\n"' > $bad/codex/window/sid.json
assert_failure 'empty-after-decoding Codex marker' \
    $bad $bad/codex/window/sid.json

bad=$work/main-id-stream
mkdir -p $bad/codex/window
printf '%s\n' '"thread-one"' '"thread-two"' > $bad/codex/window/sid.json
assert_failure 'multiple main Codex ID values' $bad $bad/codex/window/sid.json

bad=$work/empty-marker
mkdir -p $bad/grok/window
: > $bad/grok/window/sid
assert_failure 'empty UUID marker' $bad $bad/grok/window/sid

bad=$work/bad-uuid
mkdir -p $bad/claude/window
print -r -- 'not-a-uuid' > $bad/claude/window/sid
assert_failure 'malformed UUID marker' $bad $bad/claude/window/sid

bad=$work/missing-seat-pair
mkdir -p $bad/codex/window/seats/sol
write_seat_config $bad/codex/window/seats/sol/config.json window-sol
assert_failure 'missing named-seat pair' $bad $bad/codex/window/seats/sol/sid.json

bad=$work/missing-seat-config
mkdir -p $bad/codex/window/seats/sol
print -r -- '"seat-thread"' > $bad/codex/window/seats/sol/sid.json
assert_failure 'missing named-seat configuration' \
    $bad $bad/codex/window/seats/sol/config.json

bad=$work/seat-id-stream
mkdir -p $bad/codex/window/seats/sol
write_seat_config $bad/codex/window/seats/sol/config.json window-sol
printf '%s\n' '"seat-one"' '"seat-two"' \
    > $bad/codex/window/seats/sol/sid.json
assert_failure 'multiple named-seat ID values' \
    $bad $bad/codex/window/seats/sol/sid.json

bad=$work/newline-seat-marker
mkdir -p $bad/codex/window/seats/sol
write_seat_config $bad/codex/window/seats/sol/config.json window-sol
print -r -- '"\n"' > $bad/codex/window/seats/sol/sid.json
assert_failure 'empty-after-decoding named-seat marker' \
    $bad $bad/codex/window/seats/sol/sid.json

bad=$work/bad-seat-config
mkdir -p $bad/codex/window/seats/sol
write_seat_config $bad/codex/window/seats/sol/config.json wrong-sol
print -r -- '"seat-thread"' > $bad/codex/window/seats/sol/sid.json
assert_failure 'inexact named-seat address' $bad $bad/codex/window/seats/sol/config.json

bad=$work/config-stream
mkdir -p $bad/codex/window/seats/sol
printf '%s\n' \
    '{"address":"window-sol"}' \
    '{"model":"gpt-test","effort":"high"}' \
    > $bad/codex/window/seats/sol/config.json
print -r -- '"seat-thread"' > $bad/codex/window/seats/sol/sid.json
assert_failure 'multiple named-seat configuration values' \
    $bad $bad/codex/window/seats/sol/config.json

bad=$work/newline-seat-config
mkdir -p $bad/codex/window/seats/sol
jq -n \
    --arg address $'window-sol\n' \
    --arg model gpt-test \
    --arg effort high \
    '{address:$address, model:$model, effort:$effort}' \
    > $bad/codex/window/seats/sol/config.json
print -r -- '"seat-thread"' > $bad/codex/window/seats/sol/sid.json
assert_failure 'lossy named-seat configuration value' \
    $bad $bad/codex/window/seats/sol/config.json

bad=$work/missing-seat-model
mkdir -p $bad/codex/window/seats/sol
jq -n '{address:"window-sol", effort:"high"}' \
    > $bad/codex/window/seats/sol/config.json
print -r -- '"seat-thread"' > $bad/codex/window/seats/sol/sid.json
assert_failure 'missing named-seat model' \
    $bad $bad/codex/window/seats/sol/config.json

bad=$work/bad-seat-effort
mkdir -p $bad/codex/window/seats/sol
write_seat_config \
    $bad/codex/window/seats/sol/config.json window-sol gpt-test impossible
print -r -- '"seat-thread"' > $bad/codex/window/seats/sol/sid.json
assert_failure 'invalid named-seat effort' \
    $bad $bad/codex/window/seats/sol/config.json

bad=$work/bad-seat-name
mkdir -p $bad/codex/window/seats/bad-seat
write_seat_config \
    $bad/codex/window/seats/bad-seat/config.json window-bad-seat
print -r -- '"seat-thread"' > $bad/codex/window/seats/bad-seat/sid.json
assert_failure 'invalid named-seat name' \
    $bad $bad/codex/window/seats/bad-seat

bad=$work/reserved-seat-name
mkdir -p $bad/codex/window/seats/codex
write_seat_config \
    $bad/codex/window/seats/codex/config.json window-codex
print -r -- '"seat-thread"' > $bad/codex/window/seats/codex/sid.json
assert_failure 'reserved Codex seat name' \
    $bad $bad/codex/window/seats/codex

bad=$work/collision
mkdir -p $bad/codex/window/seats/fable $bad/fable/window
write_seat_config $bad/codex/window/seats/fable/config.json window-fable
print -r -- '"seat-thread"' > $bad/codex/window/seats/fable/sid.json
print -r -- 'dddddddd-dddd-4ddd-8ddd-dddddddddddd' > $bad/fable/window/sid
assert_failure 'duplicate participant address' $bad $bad/fable/window/sid

bad=$work/bad-topic
mkdir -p $bad/omp/window
print -r -- 'bad-topic' > $bad/omp/window/active
assert_failure 'invalid active OMP topic' $bad $bad/omp/window/active

bad=$work/bad-model
mkdir -p $bad/omp/window/topics/topic
print -r -- topic > $bad/omp/window/active
print -r -- unsupported > $bad/omp/window/topics/topic/model
assert_failure 'invalid active OMP model' $bad $bad/omp/window/topics/topic/model

bad=$work/symlink-file
mkdir -p $bad/codex/window
print -r -- '"linked-thread"' > $bad/target
ln -s $bad/target $bad/codex/window/sid.json
assert_failure 'symlinked registration file' $bad $bad/codex/window/sid.json

bad=$work/symlink-directory
mkdir -p $bad/real
print -r -- 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee' > $bad/real/sid
mkdir -p $bad/fable
ln -s $bad/real $bad/fable/window
assert_failure 'symlinked registration directory' $bad $bad/fable/window

bad=$work/unreadable
mkdir -p $bad/grok/window
print -r -- 'ffffffff-ffff-4fff-8fff-ffffffffffff' > $bad/grok/window/sid
chmod 000 $bad/grok/window/sid
assert_failure 'unreadable registration file' $bad $bad/grok/window/sid
chmod 600 $bad/grok/window/sid

bad=$work/inaccessible-codex-window
mkdir -p $bad/codex/alpha $bad/codex/zulu
print -r -- '"good-thread"' > $bad/codex/alpha/sid.json
chmod 000 $bad/codex/zulu
assert_failure 'inaccessible Codex window beside a good row' \
    $bad $bad/codex/zulu
chmod 700 $bad/codex/zulu

bad=$work/inaccessible-uuid-window
mkdir -p $bad/fable/alpha $bad/fable/zulu
print -r -- 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa' > $bad/fable/alpha/sid
chmod 000 $bad/fable/zulu
assert_failure 'inaccessible UUID-harness window beside a good row' \
    $bad $bad/fable/zulu
chmod 700 $bad/fable/zulu

bad=$work/inaccessible-omp-window
mkdir -p $bad/omp/alpha/topics/topic $bad/omp/zulu
print -r -- topic > $bad/omp/alpha/active
print -r -- opus > $bad/omp/alpha/topics/topic/model
chmod 000 $bad/omp/zulu
assert_failure 'inaccessible OMP window beside a good row' \
    $bad $bad/omp/zulu
chmod 700 $bad/omp/zulu

bad=$work/dangling-codex-window
mkdir -p $bad/codex/alpha
print -r -- '"good-thread"' > $bad/codex/alpha/sid.json
ln -s $bad/missing $bad/codex/zulu
assert_failure 'dangling Codex window symlink beside a good row' \
    $bad $bad/codex/zulu

bad=$work/dangling-uuid-window
mkdir -p $bad/grok/alpha
print -r -- 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' > $bad/grok/alpha/sid
ln -s $bad/missing $bad/grok/zulu
assert_failure 'dangling UUID-harness window symlink beside a good row' \
    $bad $bad/grok/zulu

bad=$work/dangling-omp-window
mkdir -p $bad/omp/alpha/topics/topic
print -r -- topic > $bad/omp/alpha/active
print -r -- fable > $bad/omp/alpha/topics/topic/model
ln -s $bad/missing $bad/omp/zulu
assert_failure 'dangling OMP window symlink beside a good row' \
    $bad $bad/omp/zulu

if [[ ! -s $forbidden_log ]]; then
    pass 'inventory never invokes wake, probe, process, or harness executables'
else
    fail 'inventory never invokes wake, probe, process, or harness executables' \
        "$(<$forbidden_log)"
fi

if (( failures )); then
    print -r -u 2 -- "windows: $failures assertion(s) failed"
    exit 1
fi
print -r -- 'windows: all assertions passed'
