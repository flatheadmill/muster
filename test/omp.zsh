#!/usr/bin/env zsh

emulate -L zsh
typeset root=${ZSH_ARGZERO:A:h:h}
typeset zshctl=${ZSHCTL:-$(command -v zshctl)}
typeset command_timeout=${commands[timeout]:-${commands[gtimeout]}}
[[ -n $command_timeout ]] || { print -ru2 -- 'omp: timeout is required'; exit 1; }
typeset work=$(mktemp -d ${TMPDIR:-/tmp}/muster-omp.XXXXXX) || exit 1
trap 'rm -rf -- $work' EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM
typeset fake_bin=$work/bin fixture_home state room pane run_out run_err
integer failures=0 case_number=0 run_code=0
mkdir -p $fake_bin
export MUSTER_TEST_OMP_CALLS=$work/omp-calls
export MUSTER_TEST_ROOT=$root MUSTER_TEST_WORK=$work
: > $MUSTER_TEST_OMP_CALLS

cat > $fake_bin/tmux <<'EOF'
#!/usr/bin/env zsh
typeset server=default
if [[ $1 == -L ]]; then server=$2; shift 2; fi
case $1 in
    (has-session)
        if [[ -n $MUSTER_TEST_TMUX_ERROR ]]; then print -ru2 -- "$MUSTER_TEST_TMUX_ERROR"; exit 1; fi
        grep -qxF "$server:${${@: -1}#=}" "$MUSTER_TEST_SESSIONS" && exit 0
        print -ru2 -- "can't find session: ${${@: -1}#=}"
        exit 1
        ;;
    (new-session)
        jq -cn --args '$ARGS.positional' -- "$@" >> "$MUSTER_TEST_LAUNCHES"
        while (( $# )); do
            if [[ $1 == -s ]]; then
                print -r -- "$server:$2" >> "$MUSTER_TEST_SESSIONS"
                break
            fi
            shift
        done
        ;;
    (display-message) print -r -- fixture-client ;;
    (list-panes|list-windows|display-popup|set-option|unbind-key|bind-key|rename-window) ;;
    (*) print -ru2 -- "unexpected tmux invocation: $*"; exit 98 ;;
esac
EOF
cat > $fake_bin/omp <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$MUSTER_TEST_OMP_CALLS"
exit 98
EOF
cat > $fake_bin/mv <<'EOF'
#!/usr/bin/env zsh
/bin/mv "$@" || exit $?
if [[ -n $MUSTER_TEST_FAIL_AFTER && ${2:t} == $MUSTER_TEST_FAIL_AFTER ]]; then exit 86; fi
EOF
cat > $fake_bin/mkdir <<'EOF'
#!/usr/bin/env zsh
/bin/mkdir "$@" || exit $?
if [[ $MUSTER_TEST_FAIL_AFTER == marker && ${${@: -1}:t} == .widget.migrating ]]; then exit 86; fi
EOF
cat > $fake_bin/timeout <<'EOF'
#!/bin/sh
shift
exec "$@"
EOF
cat > $fake_bin/fswatch <<'EOF'
#!/bin/sh
exit 99
EOF
chmod +x $fake_bin/*

# Use the real mailbox handlers and ownership checks, replacing only the
# nudge process boundary so registered Codex fixtures never wake a real thread.
cat > $work/send.zsh <<'EOF'
emulate -L zsh
typeset -A zshctl
source "$MUSTER_TEST_ROOT/bin/muster"
source "$MUSTER_TEST_ROOT/share/muster/commands/messages/send/remote/command.zsh"
function abend { printf "$1\n" "${@:2}" >&2; exit 1; }
zshctl[argzero]=$MUSTER_TEST_WORK/nudge
:execute:messages:send:remote
EOF
cat > $work/nudge <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$MUSTER_TEST_WORK/nudges"
cat >/dev/null
EOF
chmod +x $work/nudge

function check {
    typeset description=$1
    shift
    if "$@" >/dev/null; then
        print -r -- "ok: $description"
    else
        print -ru2 -- "FAIL: $description (exit=$run_code; $run_err)"
        (( failures++ ))
    fi
}

function reset_case {
    (( case_number++ ))
    fixture_home=$work/case-$case_number/home
    state=$work/case-$case_number/state
    room=$state/omp/widget
    pane=$fixture_home/pane/widget
    mkdir -p $pane/.omp
    export MUSTER_TEST_SESSIONS=$work/case-$case_number/sessions
    export MUSTER_TEST_LAUNCHES=$work/case-$case_number/launches
    export MUSTER_TEST_FAIL_AFTER=
    export MUSTER_TEST_TMUX_ERROR=
    : > $MUSTER_TEST_SESSIONS
    : > $MUSTER_TEST_LAUNCHES
    print -r -- 'modelRoles: {default: "provider/auditor:high"}' > $pane/.omp/config.yml
    declaration audit
}

function run_fixture {
    $command_timeout 5s env -u CODEX_HOME -u CLAUDE_CONFIG_DIR -u GROK_HOME -u MUSTER_MESSAGES_SSH \
        HOME=$fixture_home XDG_CONFIG_HOME=$fixture_home/.config \
        MUSTER_STATE_HOME=$state PATH=$fake_bin:$PATH TMUX=fixture \
        ZSHCTL_HELP_TEXT=1 \
        "$@" > $work/out 2> $work/err
    run_code=$?
    run_out=$(<$work/out)
    run_err=$(<$work/err)
}

function run_muster { run_fixture $zshctl $root/bin/muster "$@"; }

function declaration {
    typeset seat=$1
    mkdir -p $pane/.omp/$seat
    if [[ $seat == audit ]]; then
        cat > $pane/.omp/audit/config.json <<'JSON'
{
  "modelRoles": {
    "default": "provider/auditor:high",
    "advisor": "provider/advisor:medium",
    "smol": "provider/small:low"
  },
  "defaultThinkingLevel": "high",
  "advisor": {"enabled": true, "syncBacklog": "1"},
  "prewalk": {"enabled": false},
  "cycleOrder": ["default", "smol"]
}
JSON
    else
        print -r -- '{"modelRoles":{"default":"provider/worker:low"},"advisor":{"enabled":false}}' \
            > $pane/.omp/$seat/config.json
    fi
}

function legacy {
    mkdir -p $room/sid/tools
    print -r -- '{"type":"session","version":3,"id":"11111111-1111-4111-8111-111111111111"}' > $room/sid.jsonl
    print -r -- advisor > $room/sid/__advisor.jsonl
    printf '\000\001\377\n' > $room/sid/tools/result
    print -r -- lock > $room/.session.lock
    print -r -- metadata > $room/unknown-metadata
}

function mailbox {
    typeset dir=$state/messages/widget-omp
    mkdir -p $dir/.inbox $dir/.outbox
    print -r -- read-message > $dir/.inbox/001
    print -r -- unread-message > $dir/.inbox/002
    print -r -- sent-message > $dir/.outbox/001
    print -r -- 001 > $dir/.read
    print -r -- 002 > $dir/.waited
}

reset_case
legacy
mailbox
cp -R $room $work/original-state
cp -R $state/messages/widget-omp $work/original-mail
cp $pane/.omp/config.yml $work/native-config
cp $pane/.omp/audit/config.json $work/audit-config
run_muster omp migrate --slug widget
check 'flat room migrates' test $run_code -eq 0
(( run_code == 0 )) || exit 1
check 'all transcript artifacts survive intact' diff -r $work/original-state $room/audit
check 'mailbox and both cursors survive intact' diff -r $work/original-mail $state/messages/widget-audit
check 'native project configuration stays unchanged' cmp $work/native-config $pane/.omp/config.yml
check 'migration retains the prepared declaration unchanged' cmp $work/audit-config $pane/.omp/audit/config.json
check 'migration removes only its finished marker' test ! -e $state/omp/.widget.migrating
run_muster omp migrate --slug widget
check 'already-converted invocation is harmless' test $run_code -eq 0
run_muster messages read --slug widget-audit
check 'audit resumes the unread mailbox cursor' test "$run_out" = $'--- message 002 ---\nunread-message'
print -r -- response | run_muster messages send --slug widget-claude --from widget-audit
check 'audit replies under its new address' test $run_code -eq 0
typeset replies=( $state/messages/widget-audit/.outbox/*(N) )
check 'audit records its new reply' test ${#replies} -eq 2

typeset operation
for operation in read listen get monitor peek transcript; do
    run_muster messages $operation --slug widget-omp
    check "$operation rejects the retired address" test $run_code -ne 0
    check "$operation names the replacement address" test "${run_err#*widget-audit}" != "$run_err"
done
check 'old mailbox is not resurrected' test ! -e $state/messages/widget-omp
print -r -- stale | run_muster messages send --slug widget-grok --from widget-omp
check 'a retired sender fails before delivery' test $run_code -ne 0
check 'a retired sender creates no recipient inbox' test ! -e $state/messages/widget-grok
print -r -- stale | run_muster messages send --slug widget-omp --from widget-fable
check 'a retired recipient fails before recording an outbox' test ! -e $state/messages/widget-fable

declaration bench
run_muster omp run --slug widget
check 'no seat argument opens audit' test $run_code -eq 0
run_muster omp run --slug widget --seat bench
check 'bench starts independently' test $run_code -eq 0
check 'seat sessions have separate identities' test "$(jq -r .id $room/bench/sid.jsonl)" != "$(jq -r .id $room/audit/sid.jsonl)"
check 'launch carries seat policy, identity and paths' jq -se '
    length == 2 and
    (.[0] | index("widget-audit") != null and index("MUSTER_SLUG=widget-audit") != null and
        index("provider/auditor:high") != null and index("--thinking") != null and index("high") != null and
        any(.[]; endswith("/.omp/audit/config.json")) and
        any(.[]; endswith("/audit/sid.jsonl"))) and
    (.[1] | index("widget-bench") != null and index("MUSTER_SLUG=widget-bench") != null and
        index("provider/worker:low") != null)
' $MUSTER_TEST_LAUNCHES
typeset bench_id=$(jq -r .id $room/bench/sid.jsonl)
run_muster omp run --slug widget --seat bench
check 'opening a live seat attaches without relaunch' test $(wc -l < $MUSTER_TEST_LAUNCHES) -eq 2
: > $MUSTER_TEST_SESSIONS
print -r -- '{"modelRoles":{"default":"provider/replacement:high"},"advisor":{"enabled":false}}' > $pane/.omp/bench/config.json
run_muster omp run --slug widget --seat bench
check 'restart preserves the transcript identity' test "$(jq -r .id $room/bench/sid.jsonl)" = "$bench_id"
check 'restart passes the edited model declaration' jq -se '.[-1] | index("provider/replacement:high") != null' $MUSTER_TEST_LAUNCHES
run_muster windows --json
check 'inventory exposes both seats' jq -e 'map(.address) == ["widget-audit","widget-bench"]' $work/out
: > $MUSTER_TEST_SESSIONS
run_muster rename --slug widget --to sprocket
check 'ordinary rename includes both OMP seats' test $run_code -eq 0
check 'rename preserves the bench transcript' test "$(jq -r .id $state/omp/sprocket/bench/sid.jsonl)" = "$bench_id"
check 'rename moves declarations with the room' test -f $fixture_home/pane/sprocket/.omp/bench/config.json
run_muster messages read --slug sprocket-omp
check 'retirement follows the renamed room' test $run_code -ne 0
check 'renamed refusal names the new audit address' test "${run_err#*sprocket-audit}" != "$run_err"

# Simulate a process failing immediately after each durable rename. Recovery
# sees the completed move, with no phase record claiming it happened.
typeset boundary
for boundary in marker legacy audit widget-audit; do
    reset_case
    legacy
    mailbox
    export MUSTER_TEST_FAIL_AFTER=$boundary
    run_muster omp migrate --slug widget
    check "interruption after $boundary fails" test $run_code -ne 0
    check "interruption after $boundary retains marker" test -d $state/omp/.widget.migrating
    [[ -d $state/omp/.widget.migrating ]] || exit 1
    run_muster windows --json
    check "inventory rejects unfinished $boundary conversion" test $run_code -ne 0
    run_muster omp run --slug widget
    check "launch rejects unfinished $boundary conversion" test $run_code -ne 0
    run_muster rename --slug widget --to sprocket
    check "rename rejects unfinished $boundary conversion" test $run_code -ne 0
    for operation in read listen get monitor; do
        run_muster messages $operation --slug widget-audit
        check "$operation rejects unfinished $boundary conversion" test $run_code -ne 0
    done
    export MUSTER_TEST_FAIL_AFTER=
    run_muster omp migrate --slug widget
    check 'an existing marker requires explicit recovery' test $run_code -ne 0
    run_muster omp migrate --slug widget --recover
    check "recovery after $boundary succeeds" test $run_code -eq 0
    check "recovery after $boundary preserves transcript bytes" diff -r $work/original-state $room/audit
    check "recovery after $boundary preserves mailbox bytes" diff -r $work/original-mail $state/messages/widget-audit
done

typeset shape
for shape in mailbox transcript neither; do
    reset_case
    [[ $shape != mailbox ]] || mailbox
    [[ $shape != transcript ]] || legacy
    run_muster omp migrate --slug widget
    check "$shape-only inventory can migrate" test $run_code -eq 0
    check "$shape inventory establishes audit identity" test -d $room/audit
    run_muster messages read --slug widget-omp
    check "$shape inventory retires the old address" test $run_code -ne 0
done

reset_case
declaration bench
run_muster omp run --slug widget --seat bench
check 'a new bench may precede audit' test $run_code -eq 0
check 'bench-first launch creates no audit transcript' test ! -e $room/audit
run_muster messages read --slug widget-omp
check 'bench-first layout retires the legacy address' test $run_code -ne 0
run_muster omp migrate --slug widget
check 'migration refuses a running bench' test $run_code -ne 0
: > $MUSTER_TEST_SESSIONS
run_muster omp migrate --slug widget
check 'bench-first layout is already seated' test $run_code -eq 0

reset_case
legacy
run_muster omp run --slug widget
check 'legacy launch gives the explicit conversion command' test "${run_err#*muster omp migrate --slug widget}" != "$run_err"
check 'refusing legacy launch creates no seat' test ! -e $room/audit
print -r -- muster-omp:widget > $MUSTER_TEST_SESSIONS
run_muster omp migrate --slug widget
check 'live legacy session prevents mutation' test ! -e $state/omp/.widget.migrating
: > $MUSTER_TEST_SESSIONS
mkdir -p $state/messages/widget-audit
run_muster omp migrate --slug widget
check 'destination mailbox collision fails' test $run_code -ne 0
check 'mailbox collision preserves legacy state' test -f $room/sid.jsonl

reset_case
mkdir -p $room/topics/widget
print -r -- widget > $room/active
run_muster omp migrate --slug widget
check 'historical topic layouts require a separate procedure' test $run_code -ne 0
check 'topic refusal leaves no transaction marker' test ! -e $state/omp/.widget.migrating

reset_case
legacy
mkdir -p $state/codex/widget/seats/audit
run_muster omp migrate --slug widget
check 'existing named Codex seat prevents takeover' test $run_code -ne 0
check 'participant collision leaves no marker' test ! -e $state/omp/.widget.migrating
typeset seat
for seat in audit bench; do
    run_muster codex create --slug widget --seat $seat --effort high
    check "$seat is reserved from Codex creation" test "${run_err#*reserved participant seat}" != "$run_err"
done

typeset layout participant registration
for layout in absent legacy; do
    for seat in audit bench; do
        reset_case
        [[ $layout != legacy ]] || legacy
        declaration $seat
        participant=widget-$seat
        registration=$state/codex/widget/seats/$seat
        mkdir -p $registration
        jq -cn --arg address $participant \
            '{address:$address, model:"provider/existing", effort:"high"}' > $registration/config.json
        print -r -- '"existing-codex-thread"' > $registration/sid.json
        : > $work/nudges
        jq -cn --arg slug $participant \
            '{slug:$slug, from:"widget-claude", message:"existing participant message"}' |
            run_fixture zsh $work/send.zsh
        check "$layout OMP state permits delivery to existing Codex $seat" test $run_code -eq 0
        check "existing Codex $seat retains its wake address" \
            grep -qxF "codex nudge --slug widget --seat $seat" $work/nudges
        run_muster messages read --slug $participant
        check "$layout OMP state permits existing Codex $seat to read" test $run_code -eq 0
        check "existing Codex $seat reads its delivered message" \
            grep -qxF 'existing participant message' $work/out
        print -r -- 'existing participant reply' |
            run_muster messages send --slug widget-claude --from $participant
        check "$layout OMP state permits existing Codex $seat to reply" test $run_code -eq 0
        run_muster windows --json
        check "inventory retains existing Codex $seat before conversion" jq -e --arg address $participant \
            'any(.[]; .address == $address and .harness == "codex")' $work/out
        run_muster omp migrate --slug widget
        check "existing Codex $seat still blocks OMP migration" \
            test "${run_err#*owned by a Codex seat}" != "$run_err"
        check 'takeover refusal creates no marker' test ! -e $state/omp/.widget.migrating
        run_muster omp run --slug widget --seat $seat
        check "existing Codex $seat still blocks OMP launch" \
            test "${run_err#*owned by a Codex seat}" != "$run_err"

        # A deliberately conflicting seated layout must still fail closed.
        [[ $layout != legacy ]] || mv $room $work/legacy-$seat
        mkdir -p $room/audit
        run_muster messages read --slug $participant
        check 'seated ownership conflict blocks mailbox access' test $run_code -ne 0
        run_muster windows --json
        check 'seated ownership conflict blocks inventory' test $run_code -ne 0
        check 'conflicting inventory emits no partial rows' test ! -s $work/out
    done
done

reset_case
declaration audit
mkdir -p $state/omp
ln -s $work/nonexistent $state/omp/.widget.migrating
run_muster omp run --slug widget
check 'dangling migration marker refuses launch' test $run_code -ne 0
run_muster messages read --slug widget-omp
check 'dangling marker cannot recreate the old inbox' test ! -e $state/messages/widget-omp
run_muster windows --json
check 'inventory sees a dangling hidden marker' test $run_code -ne 0

reset_case
declaration audit
mkdir -p $state/omp/widget
ln -s $work/nonexistent $room/audit
run_muster messages read --slug widget-omp
check 'dangling seat path refuses mailbox access' test $run_code -ne 0
check 'dangling seat path creates no mailbox' test ! -e $state/messages/widget-omp

reset_case
mkdir -p $fixture_home/.config/muster
print -r -- 'MUSTER_MESSAGES_SSH=example.invalid' > $fixture_home/.config/muster/messages.zsh
run_muster omp migrate --slug widget
check 'remote message storage is refused before mutation' test ! -e $state/omp

typeset invalid
for invalid in \
    '{}' \
    '{"modelRoles":{"default":"provider/model"},"advisor":{"enabled":false}}' \
    '{"modelRoles":{"default":"provider/model:high"},"advisor":{"enabled":true}}' \
    '{"modelRoles":{"default":"provider/model:high"},"advisor":{"enabled":"false"}}' \
    '{"modelRoles":{"default":"provider/model:high"},"defaultThinkingLevel":"invalid","advisor":{"enabled":false}}' \
    '{"modelRoles":{"default":"provider/model:high\n"},"advisor":{"enabled":false}}' \
    $'{"modelRoles":{"default":"provider/model:high"},"advisor":{"enabled":false}}\n{}'
do
    reset_case
    mkdir -p $pane/.omp/bench
    print -r -- $invalid > $pane/.omp/bench/config.json
    run_muster omp run --slug widget --seat bench
    check 'invalid declaration refuses launch' test $run_code -ne 0
    check 'invalid declaration creates no transcript' test ! -e $room
done

reset_case
mkdir -p $pane/.omp/bench
print -r -- '{"modelRoles":{"default":"provider/model"},"defaultThinkingLevel":"medium","advisor":{"enabled":false}}' > $pane/.omp/bench/config.json
run_muster omp run --slug widget --seat bench
check 'effort may be declared separately from the selector' test $run_code -eq 0
check 'separate effort is passed explicitly on launch' jq -se '.[0] | index("--thinking") != null and index("medium") != null' $MUSTER_TEST_LAUNCHES

reset_case
legacy
export MUSTER_TEST_TMUX_ERROR='error connecting to fixture (Permission denied)'
run_muster omp migrate --slug widget
check 'an inaccessible private server is not mistaken for a stopped room' test $run_code -ne 0
check 'failed session inspection leaves state untouched' test ! -e $state/omp/.widget.migrating

reset_case
declaration audit
mkdir -p $state/messages/widget-audit
run_muster omp run --slug widget
check 'fresh launch refuses an unowned existing mailbox' test $run_code -ne 0
check 'mailbox collision creates no seat state' test ! -e $room

reset_case
mkdir -p $state/messages/widget-claude/.outbox
chmod 500 $state/messages/widget-claude/.outbox
print -r -- message | run_muster messages send --slug widget-grok --from widget-claude
check 'unwritable sender outbox fails before publication' test $run_code -ne 0
check 'unwritable sender creates no recipient mailbox' test ! -e $state/messages/widget-grok
chmod 700 $state/messages/widget-claude/.outbox

typeset preparation
for preparation in missing invalid valid; do
    reset_case
    legacy
    mailbox
    print -r -- 'modelRoles: [unterminated' > $pane/.omp/config.yml
    case $preparation in
        (missing) rm -rf $pane/.omp/audit ;;
        (invalid) print -r -- '{"advisor":' > $pane/.omp/audit/config.json ;;
    esac
    cp -R $pane/.omp $work/config-before-$preparation
    run_muster omp migrate --slug widget
    if [[ $preparation == valid ]]; then
        check 'prepared policy permits conversion without reading native YAML' test $run_code -eq 0
        check 'prepared policy moves only the OMP state and mail' test -f $room/audit/sid.jsonl
    else
        check "$preparation declaration refuses conversion" test $run_code -ne 0
        check "$preparation declaration creates no marker" test ! -e $state/omp/.widget.migrating
        check "$preparation declaration preserves the source tree" diff -r $work/original-state $room
        check "$preparation declaration preserves the source mail" diff -r $work/original-mail $state/messages/widget-omp
    fi
    check "$preparation declaration leaves malformed native configuration untouched" diff -r $work/config-before-$preparation $pane/.omp
done
check 'conversion and preflight never invoke OMP configuration discovery' test ! -s $MUSTER_TEST_OMP_CALLS

(( failures == 0 )) || { print -ru2 -- "omp: $failures failure(s)"; exit 1; }
print -r -- 'omp: all assertions passed'
