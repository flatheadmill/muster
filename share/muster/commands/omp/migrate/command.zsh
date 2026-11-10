function :help:omp:migrate {
    help=$(<${functions_source[:help:omp:migrate]:A:h}/help.md)
}

function :args:omp:migrate {
    eval "$(args -bx h,help ,recover -s s,slug -- "$@")"
}

function muster_omp_flat {
    typeset dir=$1 entry
    muster_omp_directory $dir
    typeset -a entries=( $dir/*(DN) )
    (( ${#entries} )) || return 0
    for entry in active topics audit bench; do
        ! muster_omp_exists $dir/$entry ||
            abend 'fatal: migration requires flat OMP state; unexplained layout: %s' "$dir/$entry"
    done
    muster_omp_file $dir/sid.jsonl
    muster_omp_directory $dir/sid
}

function muster_omp_mailbox {
    typeset dir=$1 cursor
    muster_omp_directory $dir
    muster_omp_directory $dir/.inbox
    muster_omp_directory $dir/.outbox
    for cursor in .read .waited; do
        ! muster_omp_exists $dir/$cursor || muster_omp_file $dir/$cursor
    done
}

function muster_omp_same_device {
    typeset source=$1 parent=$2 source_device parent_device
    if [[ $OSTYPE == darwin* ]]; then
        source_device=$(stat -f %d $source) && parent_device=$(stat -f %d $parent) ||
            abend 'fatal: cannot inspect filesystem for %s' "$source"
    else
        source_device=$(stat -c %d $source) && parent_device=$(stat -c %d $parent) ||
            abend 'fatal: cannot inspect filesystem for %s' "$source"
    fi
    [[ $source_device == $parent_device ]] ||
        abend 'fatal: migration requires a same-filesystem rename: %s' "$source"
}

function :execute:omp:migrate {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    [[ $# -eq 0 ]] || abend 'fatal: usage: muster omp migrate --slug <slug> [--recover]'
    muster_window_slug $o_slug
    typeset dir=$HOME/pane/$o_slug
    muster_omp_directory $dir
    [[ -d $dir ]] || abend 'fatal: no window directory at %s' "$dir"
    muster_messages_configure
    [[ -z ${MUSTER_MESSAGES_SSH:-} ]] ||
        abend 'fatal: OMP migration requires local message storage'
    muster_omp_require_stopped $o_slug
    muster_omp_collisions $o_slug
    muster_state_root
    typeset namespace=$REPLY/omp room=$REPLY/omp/$o_slug
    typeset marker=$REPLY/omp/.${o_slug}.migrating messages=$REPLY/messages
    typeset legacy=$marker/legacy old_mail=$messages/${o_slug}-omp
    typeset new_mail=$messages/${o_slug}-audit bench_mail=$messages/${o_slug}-bench
    typeset entry
    muster_omp_directory $namespace
    muster_omp_directory $room
    muster_omp_directory $messages
    muster_omp_mailbox $old_mail
    muster_omp_mailbox $new_mail
    muster_omp_mailbox $bench_mail
    if (( o_recover )); then
        muster_omp_directory $marker
        [[ -d $marker ]] || abend 'fatal: no unfinished OMP migration at %s' "$marker"
        for entry in $marker/*(DN); do
            [[ ${entry:t} == legacy ]] ||
                abend 'fatal: unexplained migration entry: %s' "$entry"
        done
    else
        muster_omp_state $o_slug
        if [[ $REPLY == seated ]]; then
            ! muster_omp_exists $old_mail ||
                abend 'fatal: legacy mailbox beside seated OMP state: %s' "$old_mail"
            for entry in audit bench; do
                [[ ! -d $room/$entry ]] || muster_omp_declaration $o_slug $entry
            done
            print -r -- "OMP room $o_slug already uses seats"
            return 0
        fi
        ! muster_omp_exists $new_mail ||
            abend 'fatal: destination mailbox already exists: %s' "$new_mail"
    fi
    ! muster_omp_exists $room/bench || abend 'fatal: bench collides with migration: %s' "$room/bench"
    ! muster_omp_exists $bench_mail || abend 'fatal: destination mailbox already exists: %s' "$bench_mail"
    muster_omp_directory $legacy
    if muster_omp_exists $room/audit; then
        muster_omp_directory $room/audit
        muster_omp_flat $room/audit
        ! muster_omp_exists $legacy || abend 'fatal: both staged and final OMP payloads exist: %s' "$marker"
        for entry in $room/*(DN); do
            [[ ${entry:t} == audit ]] || abend 'fatal: mixed OMP layout: %s' "$entry"
        done
    elif muster_omp_exists $legacy; then
        muster_omp_flat $legacy
        typeset -a entries=( $room/*(DN) )
        (( ! ${#entries} )) || abend 'fatal: both source and staged OMP payloads exist: %s' "$marker"
        ! muster_omp_exists $new_mail || abend 'fatal: mailbox moved before OMP state: %s' "$new_mail"
    else
        muster_omp_flat $room
        ! muster_omp_exists $new_mail || abend 'fatal: destination mailbox already exists: %s' "$new_mail"
    fi
    if muster_omp_exists $old_mail && muster_omp_exists $new_mail; then
        abend 'fatal: both legacy and audit mailboxes exist: %s' "$old_mail"
    fi
    [[ ! -d $room ]] || muster_omp_same_device $room $namespace
    [[ ! -d $old_mail ]] || muster_omp_same_device $old_mail $messages
    muster_omp_directory $dir/.omp
    muster_omp_directory $dir/.omp/audit
    muster_omp_directory $dir/.omp/bench
    if muster_omp_exists $dir/.omp/bench/config.json; then
        muster_omp_declaration $o_slug bench
    fi
    muster_omp_declaration $o_slug audit

    # Namespace provisioning precedes the first room mutation. The marker is
    # deliberately retained on every failure; recovery is explicit and cold.
    mkdir -p $namespace || abend 'fatal: cannot create OMP namespace: %s' "$namespace"
    if (( ! o_recover )); then
        mkdir $marker || abend 'fatal: cannot begin migration; inspect %s' "$marker"
    fi
    if [[ ! -d $room/audit ]]; then
        if [[ ! -d $legacy && -d $room ]]; then
            mv $room $legacy || abend 'fatal: cannot stage OMP room; recover %s' "$marker"
        fi
        mkdir -p $room || abend 'fatal: cannot create OMP seat container'
        if [[ -d $legacy ]]; then
            mv $legacy $room/audit || abend 'fatal: cannot install audit state; recover %s' "$marker"
        else
            mkdir $room/audit || abend 'fatal: cannot create audit state'
        fi
    fi
    if [[ -d $old_mail ]]; then
        mv $old_mail $new_mail || abend 'fatal: cannot move OMP mailbox; recover %s' "$marker"
    fi
    muster_omp_flat $room/audit
    muster_omp_declaration $o_slug audit
    muster_omp_mailbox $new_mail
    ! muster_omp_exists $old_mail && ! muster_omp_exists $legacy ||
        abend 'fatal: migration is incomplete; recover %s' "$marker"
    rmdir $marker || abend 'fatal: cannot finish migration; inspect %s' "$marker"
    print -r -- "migrated OMP room $o_slug to audit"
}
