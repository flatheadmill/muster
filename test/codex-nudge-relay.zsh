#!/usr/bin/env zsh

emulate -L zsh

typeset root=${ZSH_ARGZERO:A:h:h}
typeset relay=$root/bin/codex-nudge-relay
typeset work=$(mktemp -d ${TMPDIR:-/tmp}/muster-nudge-relay.XXXXXX) || exit 1
typeset control=$work/relay.sock queue=$work/queue log=$work/relay.log
typeset pid=

function cleanup {
    [[ -z $pid ]] || kill $pid 2>/dev/null
    rm -rf -- $work
}
trap cleanup EXIT HUP INT TERM

integer failures=0
function check {
    typeset label=$1
    shift
    if "$@"; then
        print -r -- "ok: $label"
    else
        print -r -u2 -- "FAIL: $label"
        (( failures++ ))
    fi
}

pid=$($relay --socket $work/app-server.sock --queue $queue \
    --control $control --start --log $log) || exit 1

integer attempt
for attempt in {1..50}; do
    $relay --control $control --probe && break
    sleep 0.02
done
check 'a started relay answers its control probe' $relay --control $control --probe
check 'the control endpoint is a Unix socket' test -S $control

kill $pid || exit 1
wait $pid 2>/dev/null
pid=
for attempt in {1..50}; do
    $relay --control $control --probe || break
    sleep 0.02
done
integer dead_probe=0
if $relay --control $control --probe; then
    dead_probe=1
fi
check 'a dead relay fails its control probe' test $dead_probe -eq 0

# A hard stop can leave the socket path behind; the replacement must own it.
check 'the stale control socket remains distinguishable from a live relay' test -S $control
pid=$($relay --socket $work/app-server.sock --queue $queue \
    --control $control --start --log $log) || exit 1
for attempt in {1..50}; do
    $relay --control $control --probe && break
    sleep 0.02
done
check 'a replacement relay answers through the stale path' \
    $relay --control $control --probe

(( failures == 0 )) || {
    print -r -u2 -- "codex-nudge-relay: $failures failure(s)"
    exit 1
}
print -r -- 'codex-nudge-relay: all assertions passed'
