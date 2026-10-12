#!/usr/bin/env zsh

emulate -L zsh
setopt no_unset pipe_fail

typeset root=${ZSH_ARGZERO:A:h:h}
typeset zshctl=${ZSHCTL:-$(command -v zshctl)}
[[ -n $zshctl ]] \
    || { print -r -u 2 -- 'ssh-socket: zshctl not found; set ZSHCTL'; exit 1; }

typeset work
work=$(mktemp -d ${TMPDIR:-/tmp}/muster-ssh-socket.XXXXXX) || exit 1
trap "rm -rf ${(q)work}" EXIT HUP INT TERM
mkdir -p $work/bin $work/home
mkdir -p $work/home/.local/bin
print '#!/bin/sh' > $work/home/.local/bin/muster
chmod 0755 $work/home/.local/bin/muster

[[ $OSTYPE == darwin* ]] || { print 'ssh-socket: skipped outside macOS'; exit 0; }
typeset local_agent=${SSH_AUTH_SOCK:-}
[[ -n $local_agent && -S $local_agent ]] \
    || { print 'ssh-socket: skipped without a live SSH_AUTH_SOCK'; exit 0; }

cat > $work/bin/launchctl <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$MUSTER_LAUNCHCTL_LOG"
case "$*" in
*'getenv SSH_AUTH_SOCK')
    printf '%s\n' "$MUSTER_LOCAL_AGENT"
    ;;
*'bootout '*|*'bootstrap '*|*'kickstart '*)
    ;;
*)
    exit 1
    ;;
esac
EOF
chmod 0755 $work/bin/launchctl

export MUSTER_LAUNCHCTL_LOG=$work/launchctl.log
export MUSTER_LOCAL_AGENT=$local_agent
typeset output=$(HOME=$work/home PATH=$work/bin:$PATH \
    SSH_AUTH_SOCK=$work/forwarded-agent $zshctl $root/bin/muster ssh socket refresh) || exit 1

[[ $output == "$work/home/.ssh/agent/local -> $local_agent" ]] || exit 1
[[ -L $work/home/.ssh/agent/local ]] || exit 1
[[ $(readlink $work/home/.ssh/agent/local) == $local_agent ]] || exit 1
[[ $(<$MUSTER_LAUNCHCTL_LOG) == *'getenv SSH_AUTH_SOCK' ]] || exit 1
[[ $(<$MUSTER_LAUNCHCTL_LOG) != *bootstrap* ]] || exit 1

HOME=$work/home PATH=$work/bin:$PATH MUSTER_STATE_HOME=$work/state \
    $zshctl $root/bin/muster ssh socket install >/dev/null || exit 1
typeset plist=$work/home/Library/LaunchAgents/com.flatheadmill.muster.ssh-socket.plist
plutil -lint $plist >/dev/null || exit 1
[[ $(grep -c '^<?xml version=' $plist) == 1 ]] || exit 1
[[ $(/usr/libexec/PlistBuddy -c 'Print :Label' $plist) == com.flatheadmill.muster.ssh-socket ]] || exit 1
[[ $(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' $plist) == $work/home/.local/bin/muster ]] || exit 1
[[ $(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:3' $plist) == refresh ]] || exit 1

print 'ssh-socket: refresh and scheduled installation are valid'
