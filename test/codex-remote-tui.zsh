#!/bin/zsh

emulate -L zsh
setopt errexit nounset pipefail

typeset root=${0:A:h:h}
typeset fixture=$(mktemp -d ${TMPDIR:-/tmp}/muster-remote.XXXXXX)
typeset slug=muster_remote_test_$$
typeset room=$HOME/pane/$slug
[[ ! -e $room ]] || exit 1
trap 'rm -rf -- "$fixture" "$room"' EXIT
typeset -gx MUSTER_STATE_HOME=$fixture/state
typeset -gx MUSTER_TEST_OUTPUT=$fixture/output
typeset -gx PATH=$fixture/bin:$PATH
typeset -A zshctl=(argzero $fixture/bin/muster)

mkdir -p $fixture/bin $MUSTER_TEST_OUTPUT $MUSTER_STATE_HOME/codex/$slug $room
printf '"test-thread"\n' > $MUSTER_STATE_HOME/codex/$slug/sid.json
cat > $fixture/bin/muster <<'EOF'
#!/bin/zsh
[[ "$*" == "codex nudge --slug "*" --probe" ]] || exit 1
touch $MUSTER_TEST_OUTPUT/probed
EOF
cat > $fixture/bin/codex <<'EOF'
#!/bin/zsh
if [[ $1 == app-server ]]; then
    printf '%s\n' "$@" > $MUSTER_TEST_OUTPUT/server-argv
    exit 0
fi
[[ -f $MUSTER_TEST_OUTPUT/probed ]] || exit 1
[[ $1 == resume && $2 == --remote && $3 == unix://* ]] || exit 1
for arg in "$@"; do
    case $arg in
        (--sandbox|--ask-for-approval|--add-dir|approvals_reviewer=*|sandbox_workspace_write.*)
            printf 'Remote tasks reject permission override: %s\n' "$arg" >&2
            exit 1
            ;;
    esac
done
printf '%s\n' "$@" > $MUSTER_TEST_OUTPUT/argv
EOF
chmod +x $fixture/bin/{muster,codex}

source $root/bin/muster
source $root/share/muster/commands/codex/command.zsh
source $root/share/muster/commands/codex/tui/command.zsh
function abend { printf "$1\n" "${@:2}" >&2; exit 1; }
function codex_pane_configure { return 0; }
typeset o_slug=$slug

codex_daemon_settings $slug
print -r -- $codex_daemon_resume_config | jq -e --arg room "$room" --arg code "$HOME/code" '
    .cwd == $room
    and .sandbox == "workspace-write"
    and .approvalPolicy == "on-request"
    and .approvalsReviewer == "auto_review"
    and (.config.sandbox_workspace_write.writable_roots | index($code)) != null
    and .config.sandbox_workspace_write.network_access == true
' >/dev/null

$root/bin/codex-nudge --socket $fixture/server.sock --start-server \
    --log $fixture/server.log --resume-config $codex_daemon_resume_config >/dev/null
for attempt in {1..100}; do
    [[ ! -f $MUSTER_TEST_OUTPUT/server-argv ]] || break
    sleep 0.01
done
typeset -a server_args=( "${(@f)$(<$MUSTER_TEST_OUTPUT/server-argv)}" )
typeset expected='sandbox_mode="workspace-write"'
(( server_args[(Ie)$expected] ))
expected=sandbox_workspace_write.network_access=true
(( server_args[(Ie)$expected] ))
typeset roots=$(jq -c '.config.sandbox_workspace_write.writable_roots' <<< $codex_daemon_resume_config)
expected=sandbox_workspace_write.writable_roots=$roots
(( server_args[(Ie)$expected] ))
[[ ${(j: :)server_args} != *mcp_servers* && ${(j: :)server_args} != *MUSTER_SLUG* ]]

(:execute:codex:tui --no-alt-screen)
typeset -a received=( "${(@f)$(<$MUSTER_TEST_OUTPUT/argv)}" )
[[ $received[1] == resume && $received[2] == --remote ]]
[[ $received[3] == unix://$MUSTER_STATE_HOME/codex/app-server.sock ]]
[[ $received[-2] == --no-alt-screen && $received[-1] == test-thread ]]
printf 'Remote TUI attaches after server configuration, without permission overrides.\n'
