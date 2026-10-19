#!/usr/bin/env zsh

emulate -L zsh
setopt pipefail no_bgnice
zmodload zsh/system zsh/zselect
umask 077

typeset root=${ZSH_ARGZERO:A:h:h}
typeset zshctl=${ZSHCTL:-$(command -v zshctl)}
[[ -n $zshctl ]] || { print -ru2 -- 'monitor: zshctl not found; set ZSHCTL'; exit 1; }
typeset work=$(mktemp -d ${TMPDIR:-/tmp}/muster-monitor.XXXXXX) || exit 1
typeset muster=$work/bin/muster producer=$root/test/fixtures/monitor/producer.zsh
typeset case_dir=''
integer failures=0 monitor=0 result=0 pipe_fd=-1

mkdir -p $work/bin $work/share/muster/commands/codex/nudge
cp $root/bin/muster $muster
cp -R $root/share/muster/commands/monitor $work/share/muster/commands/
print -r -- 'function :execute:codex { delegate "$@"; }' > $work/share/muster/commands/codex/command.zsh
cp $root/test/fixtures/monitor/nudge.zsh $work/share/muster/commands/codex/nudge/command.zsh
# The copied entry point retains the real parser and dispatch. Keep local user
# extensions out of the fixture, and use the selected zshctl for child nudges too.
print -r -- 'zshctl[localized]=0' >> $muster
ln -s ${zshctl:A} $work/bin/zshctl
export PATH=$work/bin:$PATH

function check {
    typeset description=$1
    shift
    if "$@" >/dev/null; then
        print -r -- "ok: $description"
    else
        print -ru2 -- "FAIL: $description"
        (( failures++ ))
    fi
}

function await_file {
    integer attempts
    for (( attempts=0; attempts < 500; attempts++ )); do
        [[ ! -s $1 ]] || return 0
        zselect -t 1
    done
    print -ru2 -- "timed out waiting for ${1:t}"
    return 1
}

function await_exit {
    integer attempts
    for (( attempts=0; attempts < 800; attempts++ )); do
        kill -0 $1 2>/dev/null || return 0
        zselect -t 1
    done
    return 1
}

function cleanup_processes {
    # Release acceptance, then stop every recorded fixture child. A timeout
    # must not leave the monitor waiting on a nudge or a surviving producer.
    typeset file
    integer pid
    if [[ -n $case_dir ]]; then
        : > $case_dir/release
        for file in $case_dir/producer.pid(N) $case_dir/nudge.*.pid(N); do
            pid=$(<$file)
            (( pid > 0 )) && kill -TERM $pid 2>/dev/null
        done
    fi
    if (( monitor )); then
        kill -TERM $monitor 2>/dev/null
        await_exit $monitor || kill -KILL $monitor 2>/dev/null
        wait $monitor 2>/dev/null
        monitor=0
    fi
    if [[ -n $case_dir ]]; then
        for file in $case_dir/producer.pid(N) $case_dir/nudge.*.pid(N); do
            pid=$(<$file)
            if (( pid > 0 )) && kill -0 $pid 2>/dev/null; then
                kill -KILL $pid 2>/dev/null
                await_exit $pid || print -ru2 -- "fixture process did not exit: $pid"
            fi
        done
    fi
    if (( pipe_fd >= 0 )); then
        exec {pipe_fd}>&-
        pipe_fd=-1
    fi
}

trap 'cleanup_processes; rm -rf -- "$work"; exit 130' INT
trap 'cleanup_processes; rm -rf -- "$work"; exit 143' TERM HUP

function setup_case {
    cleanup_processes
    case_dir=$work/$1
    mkdir -p $case_dir
    export MONITOR_TEST_ROOT=$case_dir
    unset MONITOR_TEST_HOLD MONITOR_TEST_FAIL
}

function start {
    $zshctl $muster monitor --slug scratch -- $producer "$@" > $case_dir/out 2> $case_dir/err &
    monitor=$!
}

function finish {
    if ! await_exit $monitor; then
        check 'monitor terminates within the test deadline' false
        cleanup_processes
        result=124
        return 1
    fi
    wait $monitor
    result=$?
    monitor=0
}

function reaped {
    integer pid=$(<$1)
    ! kill -0 $pid 2>/dev/null
}

function no_calls { [[ ! -s $case_dir/calls ]] }

{
    setup_case framing
    typeset literal='  a\b "$()"  '
    export MONITOR_TEST_HOLD=1
    start framing "$literal"
    check 'first nudge reaches acceptance gate' await_file $case_dir/nudging
    check 'only the first nudge has begun while held' jq -es 'length==1' $case_dir/calls
    : > $case_dir/release
    finish
    check 'producer exit status propagates' test $result -eq 7
    printf '%s\n%s\n' "$literal" $'second\r' > $case_dir/expected
    check 'stdout preserves spaces, backslash, CR and framing LF, skipping blank lines' cmp -s $case_dir/expected $case_dir/out
    check 'nudge receives exact lines and slug arguments' jq -es --arg first "$literal" '
        map(.text)==[$first+"\n","second\r\n"] and all(.[]; .args==["--slug","scratch"])
    ' $case_dir/calls
    check 'producer stderr remains stderr' grep -Fxq 'producer diagnostic' $case_dir/err
    check 'nudge diagnostics remain stderr' grep -Fxq 'nudge diagnostic' $case_dir/err
    # This final order, not the absence of a second call at one instant, proves
    # each acceptance finished before the next one began. No clocks are compared.
    jq -r '"begin \(.pid)", "end \(.pid)"' $case_dir/calls > $case_dir/expected-events
    check 'nudges finish serially in call order' cmp -s $case_dir/expected-events $case_dir/events
    typeset pid_file
    for pid_file in $case_dir/nudge.*.pid(N); do
        check 'completed nudge is reaped' reaped $pid_file
    done

    typeset tail
    integer variant=0
    for tail in tail '   '; do
        setup_case partial-$(( ++variant ))
        start partial "$tail"
        finish
        check 'unterminated tail overrides producer status with failure' test $result -eq 1
        print -r -- complete > $case_dir/expected
        check 'only complete record reaches local stdout' cmp -s $case_dir/expected $case_dir/out
        check 'unterminated tail is diagnosed' grep -q unterminated $case_dir/err
        check 'unterminated tail is never nudged, even when blank' jq -es 'map(.text)==["complete\n"]' $case_dir/calls
    done

    setup_case nudge-failure
    export MONITOR_TEST_FAIL=9
    start failure
    finish
    check 'failed nudge status propagates' test $result -eq 9
    print -r -- first > $case_dir/expected
    check 'failed nudge stops before the second output line' cmp -s $case_dir/expected $case_dir/out
    check 'uncertain delivery is not retried' jq -es 'map(.text)==["first\n"]' $case_dir/calls
    check 'failed nudge reports uncertainty' grep -q uncertain $case_dir/err
    check 'failed nudge stops producer with TERM' test "$(<$case_dir/signal)" = 15
    check 'failed nudge reaps producer' reaped $case_dir/producer.pid

    typeset phase signal
    integer number
    for phase in read nudge wait; do
        for signal in INT TERM HUP; do
            setup_case signal-$phase-$signal
            case $signal in
                (INT) number=2 ;;
                (TERM) number=15 ;;
                (HUP) number=1 ;;
            esac
            export MONITOR_TEST_HOLD=1
            start $phase
            check "$signal during $phase: producer is ready" await_file $case_dir/producer.pid
            if [[ $phase == nudge ]]; then
                check "$signal during nudge: acceptance is pending" await_file $case_dir/nudging
            elif [[ $phase == wait ]]; then
                check "$signal during wait: producer closed stdout" await_file $case_dir/stdout-closed
                # Give the monitor a scheduling turn to consume EOF and wait.
                zselect -t 5
            fi
            kill -$signal $monitor
            check "$signal during $phase: producer observes signal" await_file $case_dir/signal
            check "$signal during $phase: same signal is forwarded" test "$(<$case_dir/signal)" = $number
            if [[ $phase == nudge ]]; then
                check "$signal during nudge: monitor waits for acceptance" kill -0 $monitor
                check "$signal during nudge: acceptance has not ended" test "$(wc -l < $case_dir/events)" -eq 1
            fi
            : > $case_dir/release
            finish
            check "$signal during $phase: signal exit status is retained" test $result -eq $(( 128 + number ))
            check "$signal during $phase: producer is reaped" reaped $case_dir/producer.pid
            for pid_file in $case_dir/nudge.*.pid(N); do
                check "$signal during $phase: nudge is reaped" reaped $pid_file
            done
        done
    done

    setup_case broken-stdout
    mkfifo $case_dir/stdout
    sysopen -rw -o cloexec -u pipe_fd $case_dir/stdout || exit 1
    $zshctl $muster monitor --slug scratch -- $producer broken > $case_dir/stdout 2> $case_dir/err &
    monitor=$!
    check 'broken stdout: producer waits before printing' await_file $case_dir/producer.pid
    exec {pipe_fd}>&-
    pipe_fd=-1
    : > $case_dir/go
    finish
    check 'broken stdout fails' test $result -ne 0
    check 'broken stdout makes no nudge attempt' no_calls
    check 'broken stdout reaps producer' reaped $case_dir/producer.pid

    setup_case arguments
    typeset -a arguments=( '' --help -- 'a b' "\$(touch $case_dir/should-not-exist)" $'one\ntwo' )
    start arguments "${(@)arguments}"
    finish
    check 'exact producer argv succeeds' test $result -eq 0
    jq -cn --args '$ARGS.positional' -- "${(@)arguments}" > $case_dir/expected
    check 'producer argv is preserved, including empty fields and newlines' cmp -s $case_dir/expected $case_dir/out
    check 'nudge receives the same exact argv record' jq -es --slurpfile expected $case_dir/expected \
        'length==1 and (.[0].text|fromjson)==$expected[0]' $case_dir/calls
    check 'producer arguments are never evaluated' test ! -e $case_dir/should-not-exist

    setup_case empty
    start empty
    finish
    check 'empty producer succeeds' test $result -eq 0
    check 'empty producer emits no stdout' test ! -s $case_dir/out
    check 'empty producer makes no nudge attempt' no_calls

    setup_case grammar
    $zshctl $muster monitor --slug scratch -- /no/such/monitor-producer > $case_dir/out 2> $case_dir/err
    check 'missing executable exits 127' test $? -eq 127
    $zshctl $muster monitor --slug scratch true > $case_dir/out 2> $case_dir/err
    check 'missing command separator is rejected' test $? -ne 0
    $zshctl $muster monitor --slug scratch printf -- $'unexpected\n' > $case_dir/out 2> $case_dir/err
    check 'late command separator is rejected' test $? -ne 0
    check 'late separator never runs the producer' test ! -s $case_dir/out
    check 'grammar errors never nudge' no_calls
} always {
    cleanup_processes
    if (( failures )); then
        print -ru2 -- "fixture retained: $work"
    else
        rm -rf -- $work
    fi
}
(( failures == 0 )) || { print -ru2 -- "monitor: $failures failure(s)"; exit 1; }
print -r -- 'monitor: all process and framing checks passed'
