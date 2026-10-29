#!/usr/bin/env zsh

emulate -L zsh

typeset root=${ZSH_ARGZERO:A:h:h}
typeset zshctl=${ZSHCTL:-$(command -v zshctl)}
[[ -n $zshctl ]] \
    || { print -r -u 2 -- 'messages-send: zshctl not found; set ZSHCTL'; exit 1; }

typeset work
work=$(mktemp -d ${TMPDIR:-/tmp}/muster-messages-send.XXXXXX) || exit 1
trap "rm -rf ${(q)work}" EXIT HUP INT TERM

typeset home=$work/home state=$work/state fake_bin=$work/bin
typeset stdout_file=$work/stdout stderr_file=$work/stderr
mkdir -p $home/pane/widget $fake_bin

cat > $fake_bin/timeout <<'EOF'
#!/bin/sh
case ${MUSTER_TEST_TIMEOUT_MODE:-pass} in
    (expire) exit 124 ;;
    (pass) shift; exec "$@" ;;
    (*) exit 125 ;;
esac
EOF
chmod +x $fake_bin/timeout

integer failures=0
function pass { print -r -- "ok: $1"; }
function fail { print -r -u 2 -- "FAIL: $1"; (( failures++ )); }
function check {
    typeset name=$1
    shift
    if "$@"; then pass "$name"; else fail "$name"; fi
}

print -r -- 'Review the change.' |
    HOME=$home MUSTER_STATE_HOME=$state PATH=$fake_bin:$PATH \
    $zshctl $root/bin/muster messages send --slug widget-astra --from widget \
    > $stdout_file 2> $stderr_file
integer result=$?
check 'piped send succeeds' test $result -eq 0
check 'piped send emits no error' test ! -s $stderr_file
typeset delivered=( $state/messages/widget-astra/.inbox/*(N.) )
typeset recorded=( $state/messages/widget/.outbox/*(N.) )
check 'piped send delivers one message' test ${#delivered} -eq 1
check 'piped send records one outbox copy' test ${#recorded} -eq 1
check 'piped send preserves the message' grep -qxF 'Review the change.' $delivered[1]

MUSTER_TEST_TIMEOUT_MODE=expire \
    HOME=$home MUSTER_STATE_HOME=$state PATH=$fake_bin:$PATH \
    $zshctl $root/bin/muster messages send --slug widget-astra --from widget \
    < /dev/null > $stdout_file 2> $stderr_file
result=$?
check 'forgotten input exits nonzero' test $result -ne 0
check 'forgotten input emits no output' test ! -s $stdout_file
check 'forgotten input explains the pipeline' \
    grep -qF "print -r -- 'message' | muster messages send --slug widget-astra" $stderr_file
delivered=( $state/messages/widget-astra/.inbox/*(N.) )
check 'forgotten input delivers nothing' test ${#delivered} -eq 1

(( failures == 0 )) || { print -r -u 2 -- "messages-send: $failures failure(s)"; exit 1; }
print -r -- 'messages-send: all assertions passed'
