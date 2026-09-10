#!/bin/zsh

emulate -L zsh
setopt errexit nounset pipefail

typeset root=${0:A:h:h}
typeset fixture=$(mktemp -d ${TMPDIR:-/tmp}/muster-participants.XXXXXX)
typeset slug=muster_participant_test_$$
typeset room=$HOME/pane/$slug
[[ ! -e $room ]] || exit 1
trap 'rm -rf -- "$fixture" "$room"' EXIT
typeset -gx XDG_CONFIG_HOME=$fixture/config
typeset -gx MUSTER_STATE_HOME=$fixture/state
unset MUSTER_CODEX_MODEL MUSTER_CODEX_EFFORT MUSTER_CODEX_SERVICE_TIER
unset MUSTER_SOL_MODEL MUSTER_SOL_EFFORT MUSTER_ASTRA_MODEL MUSTER_ASTRA_EFFORT
unset MUSTER_CLAUDE_MODEL MUSTER_CLAUDE_EFFORT MUSTER_FABLE_MODEL MUSTER_FABLE_EFFORT
typeset -A zshctl
source $root/bin/muster
source $root/share/muster/commands/codex/command.zsh
source $root/share/muster/commands/codex/create/command.zsh
function abend { printf "$1\n" "${@:2}" >&2; exit 1; }

muster_participant_settings codex
[[ $muster_participant_model == gpt-5.6-sol && -z $muster_participant_effort ]]
muster_participant_settings astra
[[ $muster_participant_model == gpt-6-astra && $muster_participant_effort == xhigh ]]
muster_claude_profile fable $slug
[[ $muster_claude_model == 'claude-fable-5-1[1m]' && $muster_claude_effort == high ]]
codex_daemon_settings $slug
jq -e '(has("effort") | not) and (has("serviceTier") | not)
    and (.config | has("model_reasoning_effort") | not)' \
    <<< $codex_daemon_resume_config >/dev/null

mkdir -p $XDG_CONFIG_HOME/muster $room
cat > $XDG_CONFIG_HOME/muster/participants.zsh <<'EOF'
typeset -gx MUSTER_CODEX_MODEL=${MUSTER_CODEX_MODEL:-gpt-6-astra}
typeset -gx MUSTER_CODEX_EFFORT=${MUSTER_CODEX_EFFORT:-max}
typeset -gx MUSTER_CODEX_SERVICE_TIER=${MUSTER_CODEX_SERVICE_TIER:-fast}
typeset -gx MUSTER_ASTRA_EFFORT=${MUSTER_ASTRA_EFFORT:-max}
typeset -gx MUSTER_FABLE_EFFORT=${MUSTER_FABLE_EFFORT:-xhigh}
EOF
codex_daemon_settings $slug
jq -e '.model == "gpt-6-astra" and .config.model_reasoning_effort == "max"
    and .serviceTier == "fast" and (has("effort") | not)' \
    <<< $codex_daemon_resume_config >/dev/null
codex_daemon_settings $slug ${slug}-review gpt-5.6-sol high
jq -e '.model == "gpt-5.6-sol" and .config.model_reasoning_effort == "high"' \
    <<< $codex_daemon_resume_config >/dev/null
muster_claude_profile fable $slug
[[ $muster_claude_address == ${slug}-fable && $muster_claude_effort == xhigh ]]
if (MUSTER_ASTRA_EFFORT=invalid muster_participant_settings astra) 2>/dev/null; then
    printf 'Invalid effort was accepted.\n' >&2
    exit 1
fi

# Exercise seat persistence without starting a real Codex process.
function codex_session_start { printf '"test-thread"\n' > $2; }
typeset o_slug=$slug o_seat=astra o_effort=max o_model=gpt-6-astra
:execute:codex:create > $fixture/created.json
MUSTER_CODEX_MODEL=gpt-5.6-sol
MUSTER_CODEX_EFFORT=low
MUSTER_ASTRA_EFFORT=high
codex_seat_settings $slug astra
[[ $codex_seat_model == gpt-6-astra && $codex_seat_effort == max ]]
jq -e '.effort == "max" and .model == "gpt-6-astra"' $fixture/created.json >/dev/null
printf 'Participant defaults, overrides, validation, and saved max-effort seats pass.\n'
