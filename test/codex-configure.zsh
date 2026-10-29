#!/usr/bin/env zsh

emulate -L zsh
setopt extendedglob

typeset root=${ZSH_ARGZERO:A:h:h}
typeset zshctl=${ZSHCTL:-$(command -v zshctl)}
[[ -n $zshctl ]] || { print -u2 'codex-configure: zshctl not found'; exit 1; }
typeset work=$(mktemp -d ${TMPDIR:-/tmp}/muster-configure.XXXXXX) || exit 1
trap 'chmod -R u+rwX "$work"; rm -rf -- "$work"' EXIT
typeset fixture_home=$work/home state=$work/state fake_bin=$work/bin
mkdir -p "$fixture_home" "$fake_bin" "$work/log"
export MUSTER_TEST_ROOT=$root MUSTER_TEST_WORK=$work
typeset node_bin=$(node -p 'process.execPath') || exit 1
ln -s "$node_bin" "$fake_bin/node"

# Exercise the real startup, attachment, and queue code with only the process
# boundaries replaced. All state and HOME paths belong to this fixture.
cat > "$work/runner.zsh" <<'EOF'
emulate -L zsh
setopt extendedglob
typeset -A zshctl
source "$MUSTER_TEST_ROOT/bin/muster"
source "$MUSTER_TEST_ROOT/share/muster/commands/codex/command.zsh"
source "$MUSTER_TEST_ROOT/share/muster/commands/codex/tui/command.zsh"
source "$MUSTER_TEST_ROOT/share/muster/commands/codex/nudge/command.zsh"
function abend { printf "$1\n" "${@:2}" >&2; exit 1; }
function codex_pane_configure { :; }
function codex_app_server_ensure { :; }
function codex_nudge_bin { print -r -- "$MUSTER_TEST_WORK/bin/rpc"; }
function sleep {
    typeset request
    for request in "$MUSTER_STATE_HOME"/codex/nudges/requests/*(N.); do
        cp "$request" "$MUSTER_TEST_WORK/log/queued.json"
        print -r -- '{"ok":true,"output":{"accepted":true}}' \
            > "$MUSTER_STATE_HOME/codex/nudges/responses/${request:t}"
        rm "$request"
    done
}
zshctl[argzero]=$MUSTER_TEST_WORK/bin/dispatch
if [[ $1 == codex && $2 == nudge ]]; then
    shift 2
    typeset o_slug= o_seat= o_probe=0
    while (( $# )); do
        case $1 in
            (--slug) o_slug=$2; shift 2 ;;
            (--seat) o_seat=$2; shift 2 ;;
            (--probe) o_probe=1; shift ;;
            (*) exit 98 ;;
        esac
    done
    :execute:codex:nudge
else
    typeset action=$1 o_slug=$2 o_seat=${3:-} o_probe=0
    case $action in
        (settings)
            codex_daemon_settings "$o_slug"
            print -r -- "$codex_daemon_resume_config"
            ;;
        (tui) :execute:codex:tui ;;
        (nudge)
            mkdir -p "$MUSTER_STATE_HOME/codex/nudges/responses"
            :execute:codex:nudge
            ;;
        (*) exit 98 ;;
    esac
fi
EOF
cat > "$fake_bin/dispatch" <<'EOF'
#!/usr/bin/env zsh
exec zsh "$MUSTER_TEST_WORK/runner.zsh" "$@"
EOF
cat > "$fake_bin/rpc" <<'EOF'
#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
const config = JSON.parse(args[args.indexOf('--resume-config') + 1]);
const kind = args.includes('--start-thread') ? 'start' : 'probe';
fs.writeFileSync(`${process.env.MUSTER_TEST_WORK}/log/${kind}.json`, JSON.stringify(config));
process.stdout.write(JSON.stringify({threadId: 'fixture-thread'}) + '\n');
EOF
cat > "$fake_bin/codex" <<'EOF'
#!/usr/bin/env node
require('node:fs').writeFileSync(`${process.env.MUSTER_TEST_WORK}/log/tui.json`,
    JSON.stringify(process.argv.slice(2)));
EOF
cat > "$fake_bin/tmux" <<'EOF'
#!/bin/sh
echo 'unexpected tmux invocation' >&2
exit 98
EOF
cat > "$fake_bin/mv" <<'EOF'
#!/bin/sh
if [ "${MUSTER_TEST_FAIL_INSTALL:-}" = 1 ]; then exit 97; fi
exec /bin/mv "$@"
EOF
chmod +x "$fake_bin"/{dispatch,rpc,codex,tmux,mv}

integer failures=0 run_code=0
typeset run_out= run_err=
function run {
    HOME=$fixture_home MUSTER_STATE_HOME=$state PATH=$fake_bin:$PATH \
        ZSHCTL_HELP_TEXT=1 "$@" > "$work/out" 2> "$work/err"
    run_code=$?
    run_out=$(<"$work/out")
    run_err=$(<"$work/err")
}
function cli { run "$zshctl" "$root/bin/muster" "$@"; }
function configure { cli codex configure --slug widget "$@"; }
function runner { run zsh "$work/runner.zsh" "$@"; }
function check {
    typeset label=$1
    shift
    if "$@" >/dev/null; then print -r -- "ok: $label"
    else
        print -r -u2 -- "FAIL: $label (exit=$run_code stdout=$run_out stderr=$run_err)"
        (( failures++ ))
    fi
}
function succeeded { (( run_code == 0 )); }
function rejected { (( run_code != 0 )) && [[ -z $run_out && -n $run_err ]]; }
function equals { [[ $1 == $2 ]]; }
function contains { [[ $1 == *$2* ]]; }
function settings_match {
    jq -e --arg model "$1" --arg effort "$2" \
        '.model == $model and .config.model_reasoning_effort == $effort' "$3" >/dev/null
}
function no_process_logs { [[ -z $(print -rl -- "$work/log"/*(N)) ]]; }

configure --clear
check 'clearing an absent preference succeeds' succeeded
check 'clearing an absent preference succeeds without creating state' \
    test ! -e "$state"
runner settings widget
check 'missing preference uses ordinary defaults' \
    settings_match gpt-5.6-sol medium "$work/out"
check 'resume permissions admit Pinniped cache updates' jq -e \
    --arg path "$fixture_home/.config/pinniped" \
    '.runtimeWorkspaceRoots | index($path) != null' "$work/out"
check 'named permission profile admits the Pinniped directory' jq -e \
    --arg path "$fixture_home/.config/pinniped" \
    '.config.permissions.muster.workspace_roots[$path] == true' "$work/out"
check 'resume permissions admit Postcard credential renewal' jq -e \
    --arg path "$fixture_home/.config/postcard" \
    '.runtimeWorkspaceRoots | index($path) != null' "$work/out"
check 'named permission profile admits Postcard credentials' jq -e \
    --arg path "$fixture_home/.config/postcard" \
    '.config.permissions.muster.workspace_roots[$path] == true' "$work/out"
check 'resume permissions admit Postcard reader state updates' jq -e \
    --arg path "$fixture_home/.local/state/postcard" \
    '.runtimeWorkspaceRoots | index($path) != null' "$work/out"
check 'named permission profile admits the Postcard state directory' jq -e \
    --arg path "$fixture_home/.local/state/postcard" \
    '.config.permissions.muster.workspace_roots[$path] == true' "$work/out"
check 'resume permissions admit Missive session renewal' jq -e \
    --arg path "$fixture_home/.config/missive" \
    '.runtimeWorkspaceRoots | index($path) != null' "$work/out"
check 'named permission profile admits Missive configuration' jq -e \
    --arg path "$fixture_home/.config/missive" \
    '.config.permissions.muster.workspace_roots[$path] == true' "$work/out"
check 'resume permissions admit Missive reader state updates' jq -e \
    --arg path "$fixture_home/.local/state/missive" \
    '.runtimeWorkspaceRoots | index($path) != null' "$work/out"
check 'named permission profile admits the Missive state directory' jq -e \
    --arg path "$fixture_home/.local/state/missive" \
    '.config.permissions.muster.workspace_roots[$path] == true' "$work/out"
check 'reading defaults does not create state' test ! -e "$state"

configure --model gpt-6-astra --effort high
check 'configure succeeds before the room or thread exists' succeeded
check 'configure reports when the preference takes effect' \
    equals "$run_out" 'Saved main Codex preference for widget; it applies on the next Muster resume or nudge.'
typeset config=$state/codex/widget/config.json
check 'configuration contains only model and effort' jq -e \
    '. == {model:"gpt-6-astra",effort:"high"}' "$config"
check 'configure creates neither a room nor a SID' \
    test ! -e "$fixture_home/pane/widget"
check 'configure preserves the absent SID' test ! -e "$state/codex/widget/sid.json"
check 'configure invokes no harness or probe' no_process_logs
cli windows --json
check 'a preference alone is not a registration' equals "$run_out" '[]'

typeset saved=$(<"$config")
cli codex configure --model other --effort high
check 'slug is required' rejected
cli codex configure --slug bad-slug --model other --effort high
check 'invalid window slug is rejected' rejected
configure
check 'a model and effort pair or clear is required' rejected
configure --model other
check 'model requires effort' rejected
configure --effort high
check 'effort requires model' rejected
configure --clear --model other --effort high
check 'clear excludes model and effort' rejected
configure --seat sol --model other --effort high
check 'configure does not expose named-seat mutation' rejected
configure --model '' --effort high
check 'empty model is rejected' rejected
configure --model $'model\nother' --effort high
check 'control characters in a model are rejected' rejected
configure --model other --effort unsupported
check 'invalid effort is rejected' rejected
configure --model other --effort high extra
check 'positional arguments are rejected' rejected
check 'invalid arguments preserve the old preference' equals "$(<"$config")" "$saved"
MUSTER_TEST_FAIL_INSTALL=1 configure --model other --effort low
check 'failed atomic installation reports failure' rejected
check 'failed installation preserves the old preference' equals "$(<"$config")" "$saved"
check 'failed installation cleans up its temporary file' \
    equals "$(print -rl -- ${config:h}/.config.*(N))" ''
check 'configuration errors invoke no harness or probe' no_process_logs

runner tui widget
check 'first TUI creation succeeds' succeeded
check 'new thread creation uses the preference' \
    settings_match gpt-6-astra high "$work/log/start.json"
check 'TUI probe uses the same preference' \
    settings_match gpt-6-astra high "$work/log/probe.json"
check 'TUI arguments carry the same model and effort' jq -e \
    '.[index("--model") + 1] == "gpt-6-astra" and
     any(.[]; . == "model_reasoning_effort=\"high\"")' "$work/log/tui.json"
typeset sid=$(<"$state/codex/widget/sid.json")
configure --model gpt-6.1-sol --effort low
check 'changing preference leaves the SID untouched' \
    equals "$(<"$state/codex/widget/sid.json")" "$sid"
runner nudge widget <<< 'Fixture prompt.'
check 'nudge succeeds through the queue' succeeded
check 'nudge reads the newly saved preference' jq -e \
    '.thread == "fixture-thread" and .resumeConfig.model == "gpt-6.1-sol" and
     .resumeConfig.config.model_reasoning_effort == "low"' "$work/log/queued.json"
rm "$work/log/start.json"
runner tui widget
check 'resuming an existing TUI uses the new preference' \
    settings_match gpt-6.1-sol low "$work/log/probe.json"
check 'resuming does not create a new thread' test ! -e "$work/log/start.json"

print -r -- '"replacement-thread"' > "$state/codex/widget/sid.json"
runner nudge widget <<< 'Fixture prompt.'
check 'replacing the SID retains the window preference' jq -e \
    '.thread == "replacement-thread" and .resumeConfig.model == "gpt-6.1-sol"' \
    "$work/log/queued.json"
mv "$state/codex/widget" "$state/codex/renamed"
runner settings renamed
check 'moving the window state preserves its preference' \
    settings_match gpt-6.1-sol low "$work/out"
cli windows --json
check 'renamed registration keeps its thread identity' jq -e \
    '. == [{window:"renamed",address:"renamed",harness:"codex",thread_id:"replacement-thread"}]' \
    "$work/out"
mv "$state/codex/renamed" "$state/codex/widget"

mkdir -p "$state/codex/widget/seats/sol"
print -r -- '{"address":"widget-sol","model":"seat-model","effort":"xhigh"}' \
    > "$state/codex/widget/seats/sol/config.json"
print -r -- '"seat-thread"' > "$state/codex/widget/seats/sol/sid.json"
typeset seat_config=$(<"$state/codex/widget/seats/sol/config.json")
print -r -- '{invalid' > "$config"
runner tui widget sol
check 'named TUI retains its own settings despite an invalid main preference' \
    settings_match seat-model xhigh "$work/log/probe.json"
runner nudge widget sol <<< 'Fixture prompt.'
check 'named nudge retains its own settings' jq -e \
    '.thread == "seat-thread" and .resumeConfig.model == "seat-model" and
     .resumeConfig.config.model_reasoning_effort == "xhigh"' "$work/log/queued.json"

typeset invalid
for invalid in \
    '{invalid' '' 'null' '[]' \
    '{"model":"test"}' '{"model":12,"effort":"high"}' \
    '{"model":"","effort":"high"}' '{"model":" ","effort":"high"}' \
    '{"model":"test\n","effort":"high"}' '{"model":"test\u0000","effort":"high"}' \
    '{"model":"test","effort":"unsupported"}' \
    '{"model":"test","effort":"high","address":"widget"}' \
    '{"model":"one","effort":"high"} {"model":"two","effort":"low"}'
do
    print -r -- "$invalid" > "$config"
    runner settings widget
    check "malformed configuration fails: $invalid" rejected
done
rm "$work/log/probe.json"
runner tui widget
check 'malformed configuration blocks main TUI resume' rejected
check 'malformed configuration never reaches a probe' test ! -e "$work/log/probe.json"
runner nudge widget <<< 'Fixture prompt.'
check 'malformed configuration blocks a main nudge' rejected
configure --clear
check 'clear removes even malformed JSON without copying defaults' test ! -e "$config"
runner settings widget
check 'clearing restores the ordinary defaults' \
    settings_match gpt-5.6-sol medium "$work/out"
check 'configure and clear leave named-seat configuration unchanged' \
    equals "$(<"$state/codex/widget/seats/sol/config.json")" "$seat_config"
check 'clear preserves the replacement SID' \
    equals "$(<"$state/codex/widget/sid.json")" '"replacement-thread"'

ln -s "$work/missing" "$config"
runner settings widget
check 'a dangling preference symlink cannot select defaults' rejected
configure --model test --effort high
check 'configure refuses a symlinked preference' rejected
rm "$config"
configure --model test --effort high
chmod 000 "$config"
runner settings widget
check 'an unreadable preference fails' rejected
chmod 600 "$config"
chmod 000 "$state/codex/widget"
runner settings widget
check 'an inaccessible window cannot select defaults' rejected
chmod 700 "$state/codex/widget"
ln -s "$state" "$work/state-link"
typeset original_state=$state
state=$work/state-link/
runner settings widget
check 'a configured state root may be a symlink' settings_match test high "$work/out"
state=$original_state

chmod 000 "$state"
state=$original_state/hidden/state
runner settings widget
check 'an unsearchable state-root ancestor cannot select defaults' rejected
state=$original_state
chmod 700 "$state"
ln -s "$work/missing-root" "$work/dangling-root"
state=$work/dangling-root/
runner settings widget
check 'a dangling state-root symlink with a trailing slash fails' rejected
state=$original_state
rm "$config"
mkdir "$config"
runner settings widget
check 'a directory cannot masquerade as a missing preference' rejected
configure --clear
check 'clear refuses to remove a configuration directory' rejected
rmdir "$config"

cli codex configure --help
check 'configure help is available' succeeded
check 'help explains when the preference takes effect' \
    contains "$run_out" 'Changes apply on the next Muster resume or nudge'

if (( failures )); then
    print -r -u2 -- "codex-configure: $failures assertion(s) failed"
    exit 1
fi
print -r -- 'codex-configure: all assertions passed'
