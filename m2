#!/bin/sh

usage='Usage:
    morph ... command chain ...
Each word(s) in the command chain further transforms the input.
Commands marked with (*) end the chain because of how they consume the input.
Abilities:
    *avg        compute average of column 1; also "average"
    counts      run sort | uniq -c; also "count"
    cut A,B..   runs cut -d$MORPHSEP -f A,B..
    col N       selects column n
    *gather     put everything on one line, separated by SEP
    head N      runs head -n; also "take"        
    hhmm        grep -o a five-digit timestamp
    hhmmss      grep -o an eight-digit timestamp
    hide PAT    same as grep -v
    only PAT    grep -o PAT (uses Perl, so portable)
    rank        runs sort -rnk1
    sep SEP     sets MORPHSEP, field separator used by cut, gather
    sort        runs sort
    sum         compute sum of column 1
    tail N      runs tail -N 
'

while true; do case "$1" in

    avg|average)
        exec awk "-F$MORPHSEP" '{ x += $1 } END { if (NR > 0) print x/NR; }'
        ;;

    col)
        column="$2"
        shift; shift
        awk "-F$MORPHSEP" "{print \$$column;}" | $0 "$@"
        exit $?
        ;;

    count|counts)
        shift
        sort | uniq -c | $0 "$@"
        exit $?
        ;;

    rank)
        shift
        sort -nrk1 | $0 "$@"
        exit $?
        ;;

