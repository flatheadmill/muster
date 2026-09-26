#!/usr/bin/env zsh

emulate -L zsh

typeset here=${ZSH_ARGZERO:A:h}
typeset -a suites=( ${(o)here}/*.zsh(N.) )
suites=( ${suites:#${ZSH_ARGZERO:A}} )

if (( ! ${#suites} )); then
    print -r -u 2 -- 'all: no suites found'
    exit 1
fi

integer failed=0
typeset -a failures=()
typeset suite name output

for suite in "${(@)suites}"; do
    name=${${suite:t}%.zsh}
    output=$(ZSHCTL=${ZSHCTL:-} zsh $suite 2>&1)
    if (( $? )); then
        print -r -- "FAIL: $name"
        print -r -- "$output"
        print -r --
        failures+=( $name )
        (( failed++ ))
    else
        print -r -- "ok: $name (${${(@Af)output}[-1]:-no output})"
    fi
done

if (( failed )); then
    print -r -- "all: ${failed} of ${#suites} suites failed: ${(j:, :)failures}"
    exit 1
fi
print -r -- "all: ${#suites} suites passed"
