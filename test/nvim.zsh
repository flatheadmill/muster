#!/usr/bin/env zsh

emulate -L zsh

typeset root=${ZSH_ARGZERO:A:h:h}
typeset zshctl=${ZSHCTL:-$(command -v zshctl)}
[[ -n $zshctl ]] \
    || { print -r -u 2 -- 'nvim: zshctl not found; set ZSHCTL'; exit 1; }

typeset work
work=$(mktemp -d ${TMPDIR:-/tmp}/muster-nvim.XXXXXX) || exit 1
trap "rm -rf ${(q)work}" EXIT HUP INT TERM

typeset home=$work/home fake_bin=$work/bin
typeset stdout_file=$work/stdout stderr_file=$work/stderr
mkdir -p $home $fake_bin

cat > $fake_bin/nvim <<'EOF'
#!/bin/sh
set -eu
: > "$MUSTER_TEST_NVIM_ARGS"
for argument in "$@"; do printf '%s\n' "$argument" >> "$MUSTER_TEST_NVIM_ARGS"; done
case "$*" in
    (*loadfile*)
        for expression do :; done
        encoded=${expression##*, }
        encoded=${encoded%)}
        path=$(printf '%s\n' "$encoded" | jq -r .)
        printf '%s\n' "$path" > "$MUSTER_TEST_NVIM_STAGE"
        cp "$path" "$MUSTER_TEST_NVIM_CHUNK"
        printf '%s\n' '{"answer":42}'
        ;;
    (*--remote-expr*) printf '%s\n' 'expression-result' ;;
esac
EOF
chmod +x $fake_bin/nvim

export MUSTER_TEST_NVIM_ARGS=$work/args
export MUSTER_TEST_NVIM_STAGE=$work/stage
export MUSTER_TEST_NVIM_CHUNK=$work/chunk

integer failures=0 run_code=0
typeset run_out= run_err=
function pass { print -r -- "ok: $1"; }
function fail { print -r -u 2 -- "FAIL: $1"; (( failures++ )); }
function check {
    typeset name=$1
    shift
    if "$@"; then pass "$name"; else fail "$name"; fi
}
function run_muster {
    : > $stdout_file
    : > $stderr_file
    HOME=$home PATH=$fake_bin:$PATH ZSHCTL_HELP_TEXT=1 \
        $zshctl $root/bin/muster "$@" > $stdout_file 2> $stderr_file
    run_code=$?
    run_out=$(<$stdout_file)
    run_err=$(<$stderr_file)
}

run_muster nvim send --slug dotfiles-nvim '<Esc>'
check 'send succeeds' test $run_code -eq 0
check 'send expands a nested workspace slug' grep -qxF "$home/pane/dotfiles/nvim/nvim.sock" $work/args
check 'send selects remote key input' grep -qxF -- '--remote-send' $work/args
check 'send preserves the keys argument' grep -qxF '<Esc>' $work/args

NVIM_SOCKET=$work/editor.sock run_muster nvim expr 'line(".")'
check 'expression succeeds with NVIM_SOCKET' test $run_code -eq 0
check 'expression uses the environment socket' grep -qxF $work/editor.sock $work/args
check 'expression prints the remote result' test "$run_out" = expression-result

run_muster nvim lua --slug widget 'local answer = 6 * 7; return { answer = answer }'
check 'Lua argument succeeds' test $run_code -eq 0
check 'Lua argument is executed from a staged file' \
    grep -qxF 'local answer = 6 * 7; return { answer = answer }' $work/chunk
check 'Lua result remains JSON' test "$run_out" = '{"answer":42}'
typeset staged=$(<$work/stage)
check 'Lua stage is removed after execution' test ! -e $staged

print -r -- $'local value = 42\nreturn { answer = value }' |
    HOME=$home PATH=$fake_bin:$PATH ZSHCTL_HELP_TEXT=1 \
    $zshctl $root/bin/muster nvim lua --slug widget > $stdout_file 2> $stderr_file
run_code=$?
run_out=$(<$stdout_file)
check 'Lua standard input succeeds' test $run_code -eq 0
check 'Lua standard input preserves multiple lines' \
    grep -qxF 'return { answer = value }' $work/chunk

run_muster nvim expr 'line(".")'
check 'missing socket selection fails' test $run_code -ne 0
check 'missing socket selection explains the choices' \
    grep -qF -- '--slug or NVIM_SOCKET is required' $stderr_file

run_muster nvim --help
check 'parent help lists Lua' grep -qF 'lua' $stdout_file
run_muster nvim lua --help
check 'Lua help describes JSON results' grep -qF 'non-nil return value is' $stdout_file

(( failures == 0 )) || { print -r -u 2 -- "nvim: $failures failure(s)"; exit 1; }
print -r -- 'nvim: all assertions passed'
