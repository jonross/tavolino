#!/bin/sh

TL_DIR=$(dirname $0)
set -o pipefail

# Each tl step is handled by one pass through this, which pipes
# its output back through it to handle the next step.

step() {

    if [[ $# == 0 ]]; then
        # Nothing left to do
        if [ -n "$TL_FORMATTED" ]; then
            # Don't unsplit output if an earlier step has already formatted it
            cat
        else
            run unsplit
        fi

    elif [[ $1 == "--read" ]]; then
        # --read is used by handle_files, below; handle one file
        read_file "$1"

    elif [[ $1 =~ ^s[/_:=-] ]]; then
        # sed-like replacement e.g. s/lhs/rhs/g
        expr="$1"
        columns=$2
        shift; shift
        run sub "$expr" $columns | step "$@"

    elif [[ $1 =~ \..[^0-9] ]]; then
        # First arg looks like a filename so handle as many as supplied
        handle_files "$@"

    elif [[ $1 =~ ^[0-9]+$ ]]; then
        # A number N by itself is the same as "keep N"
        columns="$1"
        shift
        run keep "$columns" | step "$@"

    elif [[ $1 =~ ^\.[0-9]+ ]]; then
        # E.g. ".3" means set floating point precision to 3 places
        export TL_PRECISION=${1/./}
        shift
        step "$@"

    else case "$1.$2" in

        # Set input and output separators

        csv.*)  shift; with_fs , "$@" ;;
        psv.*)  shift; with_fs "|" "$@" ;;
        ssv.*)  shift; with_fs " " "$@" ;;
        tsv.*)  shift; with_fs "$(printf "\t")" "$@" ;;

        # Set output separators only

        to.csv) shift; shift; with_ofs "," "$@" ;;
        to.psv) shift; shift; with_ofs "|" "$@" ;;
        to.ssv) shift; shift; with_ofs " " "$@" ;;
        to.tsv) shift; shift; with_ofs "$(printf "\t")" "$@" ;;

        # Set misc options

        max.*)
            export TL_MAXCOLUMNS=$2
            shift; shift
            step "$@"
            ;;

        # Handle no-argument steps

        ord.*)
            script=$(unalias $1)
            shift
            run $script | step "$@"
            ;;

        # Handle no-argument steps that do special output formatting

        neat.*|wiki.*)
            script=$(unalias $1)
            shift
            export TL_FORMATTED=true
            run $script | step "$@"
            ;;

        # Handle one-argument steps

        add.*|cum.*|delta.*|drop.*|dup.*|keep.*|per.*|set.*)
            script=$(unalias $1)
            arg=$2
            shift; shift
            run $script $arg | step "$@"
            ;;

        # Handle two-argument steps

        round.*)
            script=$(unalias $1)
            arg1=$2
            arg2=$3
            shift; shift; shift
            run $script $arg1 $arg2 | step "$@"
            ;;

        # Handle steps implemented with ordinary Unix shell tools

        skip.*)
            count=$2
            shift; shift
            sed "1,${count}d" | step "$@"
            ;;

        *)
            echo "Unknown option: $1 $2" >&2
            exit 1
            ;;

    esac; fi

}

# Pull all files off the front of the arg list and pipe (with uncompression
# if necessary) through the next step.

handle_files() {

    files=
    lf=$(printf "\n")

    while [[ $1 =~ \..[^0-9] ]]; do
        files="$files$lf$1"
        shift
    done

    echo "$files" | sed 1d | xargs -n1 $0 --read | step "$@"

}

read_file() {

    case "$1" in
        *.Z) uncompress <"$1" ;;
        *.gz) gunzip <"$1" ;;
        *.bz) bzcat <"$1" ;;
        *) cat <"$1" ;;
    esac

}

# Handle step aliases.
#

unalias() {

    case $1 in
        *)      echo $1 ;;
    esac

}

# Set input / outut separators and run the next step.
#

with_fs() {

    export TL_IFS="$1"
    export TL_OFS="$1"
    shift
    step "$@"

}

# Set outut separator and run the next step.
#

with_ofs() {

    export TL_OFS="$1"
    shift
    step "$@"

}

# Run one of the step scripts.  We invoke the interpreter explicitly because
# (a) we want to leave the execute bit off the scripts, and (b) we can override
# it in one place, if that becomes a requirement.

run() {

    script=$1
    shift
    python $TL_DIR/$script "$@"

}

step "$@"

