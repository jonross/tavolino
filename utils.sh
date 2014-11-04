# Convert to and from *-separated values.
# csv=comma, psv=pipe, tsv=tab, wsv=whitespace a la Perl split
# Without an arg, e.g. "csv", convert from wsv to that
# With an arg, e.g. "csv tsv", convert from type 1 to type 2

csv() { xsv csv $1; }
psv() { xsv psv $1; }
tsv() { xsv tsv $1; }
wsv() { xsv wsv $1; }

xsv() {
    if [ $# = 1 ]; then
        set wsv $1
    fi
    case $1 in
        csv) split='@f = split(",")' ;;
        psv) split='@f = split("|")' ;;
        tsv) split='@f = split("\t")' ;;
        wsv) split='@f = split' ;;
    esac
    case $2 in
        csv) join='join(",", @f)' ;;
        psv) join='join("|", @f)' ;;
        tsv) join='join("\t", @f)' ;;
        wsv) join='join(" ", @f)' ;;
    esac
    perl -lpe "$split; \$_ = $join;"
}

# Like cat only stronger; understands different compression types.
# With -s, sample files only, first 20 lines of each.

dog() {
    if [[ "$1" == "-s" ]]; then
        local sample=true
        local cat="head -20"
        shift
    else
        local sample=false
        local cat=cat
    fi
    if [ $# = 0 ]; then
        $cat
    else
        for file in "$@"; do
            if $sample; then
                $(unpacker "$file") "$file" | $cat
            else
                $(unpacker "$file") "$file"
            fi
        done
    fi
}

# Apply any filter that operates on stdin to several files.
# Works on compressed files too.

apply() {
    filter="$1"
    shift
    temp=/tmp/_apply.$$
    for file in "$@"; do
        if [ -e "$file" ]; then
            $(unpacker "$file") <"$file" >$temp
            $filter <$temp | $(repacker "$file") >"$file"
        else
            echo "File $file not found" >&2
            continue
        fi
    done
    rm -f $temp
}

# True if a file looks compressed.

is_compressed() {
    [[ "$1" =~ \.(bz|gz|Z)$ ]]
}

# Return commands to unpack / repack compressed files.

unpacker() {
    case "$1" in
        *.Z)    echo "zcat" ;;
        *.bz)   echo "bzcat" ;;
        *.gz)   echo "gunzip -c" ;;
        *)      echo cat ;;
    esac
}

repacker() {
    case "$1" in
        *.Z)    echo "compress" ;;
        *.bz)   echo "bzip2" ;;
        *.gz)   echo "gzip" ;;
        *)      echo cat ;;
    esac
}

####################################################################################################

jsonx() {
    python2.7 -c 'if True:
        import json, re, sys
        data = json.loads(sys.stdin.read())
        key = "'"$1"'"
        for item in key.split(","):
            if re.match(r"^\d+$", item):
                data = data[int(item)]
            else:
                data = data[item]
        if type(data) == list:
            for item in data:
                print item
        else:
            print data
    '
}

