function :help:omp:create {
    help=$(<${functions_source[:help:omp:create]:A:h}/help.md)
}

function :args:omp:create {
    eval "$(args -bx h,help -s s,slug t,topic m,model -- "$@")"
}

function :execute:omp:create {
    [[ -v o_slug ]] || abend 'fatal: --slug is required'
    [[ -v o_topic ]] || abend 'fatal: --topic is required'
    [[ -v o_model ]] || abend 'fatal: --model is required'
    [[ $# -eq 0 ]] || abend 'fatal: usage: muster omp create --slug <slug> --topic <topic> --model <sol|opus|fable>'

    muster_window_slug $o_slug
    muster_window_slug $o_topic
    case $o_model in
        (sol|opus|fable) ;;
        (*) abend 'fatal: model must be one of sol, opus, or fable' ;;
    esac

    muster_state_root
    typeset topic_dir=$REPLY/omp/$o_slug/topics/$o_topic
    mkdir -p ${topic_dir:h}
    mkdir $topic_dir 2>/dev/null || abend 'fatal: OMP topic already exists: %s' "$o_topic"
    print -r -- $o_model > $topic_dir/model
}
