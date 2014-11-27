
if [[ $PYTHONPATH =~ modsquad ]]; then :; else
    PYTHONPATH=${PYTHONPATH}:$HOME/bin/modsquad
fi

. ~/bin/tavolino/columns.sh
. ~/bin/tavolino/filters.sh

#

some() {
    if [ $# = 0 ]; then
        head -1000
    elif [ $# -gt 3 ]; then
        _via "head -1000" "$1" "$2" "$3"
    else
        _via "head -1000" "$@"
    fi
}

all() {
    if [ $# = 0 ]; then
        cat
    else
        _via cat "$@"
    fi
}

_via() {
    filter="$1"
    shift
    for file in "$@"; do case "$file" in
        *.Z)    zcat "$file" | $filter ;;
        *.gz)   gunzip -c "$file" | $filter ;;
        *)      $filter <"$file" ;;
    esac; done
}

####################################################################################################

colid() {
    tabify python -c 'if True:
        import sys
        columns = sys.stdin.readline().strip().split("\t")
        widths = []
        for i, column in enumerate(columns):
            width = max(4, len(column) + 1)
            widths.append(width)
            sys.stdout.write(str(i+1).rjust(width))
        print
        for i in range(len(columns)):
            sys.stdout.write(columns[i].rjust(widths[i]))
        print
    '
}

nhist() {
    sort | uniq -c | sort -nk2
}

only() {
    perl -lne "print \$& if /$1/"
}

qq() {
    (
    echo "DROP TABLE IF EXISTS x_jross_group_tmp;"
    echo "CREATE TABLE x_jross_group_tmp ("
    for column in ${1//,/ }; do case $column in
        t|tm|time) echo "$column TIME," ;;
        n*) echo "${column:1} INT," ;;
        f*) echo "${column:1} FLOAT," ;;
        *) echo "$column VARCHAR(500)," ;;
    esac; done | sed '$s/,$//'
    echo ");"
    echo "COPY x_jross_group_tmp FROM STDIN;"
    cat
    echo "\\."
    echo "SELECT * FROM x_jross_group_tmp;"
    ) | psql -F, -Atq -U jross -h localhost
}

# Convert whitespace separation to tabs.
# Leaves tab separation alone.

tabify() {
    if [ true = "$MORPH_USING_TABS" ]; then
        "$@"
    else
        export MORPH_USING_TABS=true
        perl -e '
            $_ = <STDIN>;
            if (/\t/ && !/\t\t/) { # \t\t probably from prettyprinting, not tsv data
                print;
                print while <STDIN>;
            } else {
                print join("\t", split), "\n";
                print join("\t", split), "\n" while <STDIN>;
            }
        ' | "$@"
    fi
}

twikify() {
    _wikify "|*" "*|*" "*|"
}

wikify() {
    _wikify "||" "||" "||"
}

_wikify() {
    tabify perl -e "
        \$startHeader = '$1';
        \$joinHeader = '$2';
        \$endHeader = '$3';
        "'
        # wiki is human-readable so slurping stdin shouldnt be a problem
        @lines = <STDIN>;
        chomp @lines;
        $header = shift @lines;
        @header = split("\t", $header);
        if (grep(/^-?[,0-9.]+$/, @header)) {
            # some purely numeric column, so no header
            unshift(@lines, $header);
        } else {
            print $startHeader, join($joinHeader, @header), $endHeader, "\n";
        }
        foreach (@lines) {
            # twiki can right-align cells so do that for numbers
            @row = map(/^-?[,0-9.]+$/ ? "  $_" : $_, split("\t"));
            print "|", join("|", @row), "|\n";
        }
    '
}

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

