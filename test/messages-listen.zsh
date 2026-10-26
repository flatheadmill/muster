#!/usr/bin/env zsh

emulate -L zsh
setopt no_bgnice
zmodload zsh/zselect
umask 077

typeset root=${ZSH_ARGZERO:A:h:h}
typeset work=$(mktemp -d ${TMPDIR:-/tmp}/muster-messages-listen.XXXXXX) || exit 1
typeset msgdir=$work/messages/widget
typeset inbox=$msgdir/.inbox
typeset listener=0
integer failures=0

mkdir -p $inbox

function muster_require_fswatch { return 0 }
function muster_timeout_command { REPLY=messages_test_block }
function muster_address { return 0 }
function muster_messages_dir { REPLY=$msgdir }
function muster_write_cursor { print -r -- $2 > $1 }
function messages_test_block {
    while true; do
        zselect -t 100
    done
}

source $root/share/muster/commands/messages/listen/remote/command.zsh

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

function reset_case {
    rm -rf -- $msgdir
    mkdir -p $inbox
    : > $work/out
    : > $work/err
}

function listen_foreground {
    print -r -- '{"slug":"widget"}' |
        :execute:messages:listen:remote > $work/out 2> $work/err
}

function listen_background {
    print -r -- '{"slug":"widget"}' |
        :execute:messages:listen:remote > $work/out 2> $work/err &
    listener=$!
}

function cleanup {
    if (( listener )) && kill -0 $listener 2>/dev/null; then
        kill -TERM $listener 2>/dev/null
        wait $listener 2>/dev/null
    fi
    rm -rf -- $work
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM HUP

{
    reset_case
    print -r -- first > $inbox/001
    listen_foreground
    check 'unread mail emits one nudge' \
        grep -Fxq 'Please check your messages by running `muster messages read --slug widget`.' $work/out
    check 'unread mail advances the waited cursor' \
        grep -Fxq 001 $msgdir/.waited
    check 'unread mail emits no diagnostic' test ! -s $work/err

    reset_case
    print -r -- first > $inbox/001
    print -r -- 001 > $msgdir/.waited
    listen_foreground
    check 'an unread nudge repeats until read catches it' \
        grep -Fxq 'Please check your messages by running `muster messages read --slug widget`.' $work/out

    reset_case
    print -r -- first > $inbox/001
    print -r -- second > $inbox/002
    print -r -- 001 > $msgdir/.waited
    print -r -- 002 > $msgdir/.read
    listen_background
    zselect -t 20
    check 'a drained multi-message batch leaves listen blocked' kill -0 $listener
    check 'a drained multi-message batch emits no nudge' test ! -s $work/out
    check 'a drained multi-message batch emits no diagnostic' test ! -s $work/err
} always {
    cleanup
}

(( failures == 0 )) || {
    print -ru2 -- "messages-listen: $failures failure(s)"
    exit 1
}
print -r -- 'messages-listen: all cursor checks passed'
