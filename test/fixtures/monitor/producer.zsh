#!/bin/zsh -f

zmodload zsh/zselect
typeset mode=$1
shift

case $mode in
    (framing)
        print -r -- "$1"
        print -r -- ''
        print -r -- $' \t'
        print -ru2 -- 'producer diagnostic'
        print -r -- $'second\r'
        exit 7 ;;
    (partial)
        print -r -- complete
        print -rn -- "$1"
        exit 7 ;;
    (arguments)
        exec jq -cn --args '$ARGS.positional' -- "$@" ;;
    (empty) exit 0 ;;
    (read|nudge|wait|failure|broken) ;;
    (*) print -ru2 -- "unknown producer mode: $mode"; exit 99 ;;
esac

# Readiness means all signal handlers are installed. The producer stays alive
# after its output so the test can distinguish forwarding from mere EOF.
trap 'print -r -- 2 > $MONITOR_TEST_ROOT/signal; exit 0' INT
trap 'print -r -- 15 > $MONITOR_TEST_ROOT/signal; exit 0' TERM
trap 'print -r -- 1 > $MONITOR_TEST_ROOT/signal; exit 0' HUP
print -r -- $$ > $MONITOR_TEST_ROOT/producer.pid
case $mode in
    (nudge) print -r -- record ;;
    (failure) print -rl -- first second ;;
    (wait)
        exec 1>&-
        print -r -- ready > $MONITOR_TEST_ROOT/stdout-closed ;;
    (broken)
        integer attempts
        for (( attempts=0; attempts < 1000; attempts++ )); do
            [[ ! -e $MONITOR_TEST_ROOT/go ]] || break
            zselect -t 1
        done
        [[ -e $MONITOR_TEST_ROOT/go ]] || exit 124
        print -r -- first ;;
esac

# A broken monitor or test must not strand this fixture indefinitely.
zselect -t 1000
print -ru2 -- 'producer timed out waiting for its signal'
exit 124
