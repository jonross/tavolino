
####################################################################################################
#
# Column related functions.  Most of these take an optional or mandatory argument a la the field
# expression passed to cut(1), e.g. 1,3-5,8 means columns 1, 3, 4, 5, 8.  All assume their input
# is tab-separated or guess how to make it so.
#

also() {
    python2.7 -c 'if True:
        import modsquad as m, re, sys
        def get(row, index):
            if index >= len(row):
                return None
            value = m.parse_number(row[index])
            return value if value is not None else row[index]
        exprs = re.sub("c(\d+)", r"get(row, \1-1)", sys.argv[1])
        extras = eval("lambda row: [" + exprs + "]")
        for row in m.tsv_input():
            row += map(str, extras(row))
            print "\t".join(row)
    ' "$1"
}

comma() {
    python2.7 -c 'if True:
        import modsquad as m
        columns = m.parse_columns("'"$1"'")
        for row in m.tsv_input():
            for c in columns:
                if c < len(row):
                    num = m.parse_number(row[c])
                    if num is not None:
                        row[c] = "{:,}".format(num)
            print "\t".join(row)
    '
}

header() {
    python2.7 -c 'if True:
        import modsquad as m, sys
        names = sys.argv[1].split(",") if len(sys.argv) > 1 else []
        input = m.tsv_input()
        firstrow = input.next()
        if len(names) < len(firstrow):
            for c in range(len(firstrow) - len(names)):
                names.append("c" + str(c+1))
        print "\t".join(names)
        print "\t".join(firstrow)
        for row in m.tsv_input():
            print "\t".join(row)
    ' $1
}

left() {
    python2.7 -c 'if True:
        import modsquad as m
        columns = set(m.parse_columns("'"$1"'"))
        for row in m.tsv_input():
            left = []
            right = []
            for i in range(len(row)):
                if i in columns:
                    left.append(row[i])
                else:
                    right.append(row[i])
            print "\t".join(left + right)
    '
}

per() {
    python2.7 -c 'if True:
        import modsquad as m, sys
        columns = m.parse_columns("'"$1"'")
        sums = [0] + len(columns)
        for row in m.tsv_input()
            rows.append(row)
            i = 0
            for c in columns:
                value = row[c] = float(row[c])
                sums[i] += value
                i += 1
        for row in rows:
            i = 0
            for c in columns:
                row.append(round(row[c] / sums[i], 2))
                i += 1
            print "\t".join(map(str, row))
    '
}

pivot() {
    python2.7 -c 'if True:
        import collections as co, modsquad as m, sys
        indexname = sys.argv[1]
        pivot = co.defaultdict(lambda: co.defaultdict(lambda: "NaN"))
        keys = set()
        for row in m.tsv_input():
            keys.add(row[1])
            pivot[row[0]][row[1]] = row[2]
        print "\t".join([indexname] + list(keys))
        for index, dic in pivot.iteritems():
            print "\t".join([index] + [dic[key] for key in keys])
    ' "$1"
}

redate() {
    python2.7 -c 'if True:
        import datetime as dt, dateutil.parser as dp, modsquad as m
        newformat = "'"$1"'"
        columns = m.parse_columns("'"$2"'")
        for row in m.tsv_input():
            for c in columns:
                epoch = m.as_integer(row[c])
                if epoch is not None:
                    date = dt.datetime.fromtimestamp(epoch)
                else:
                    try:
                        date = dp.parse(row[c])
                    except ValueError as e:
                        m.die("Failed to parse " + row[c] + " as date")
                row[c] = date.strftime(newformat)
            print "\t".join(row)
    '
}

right() {
    python2.7 -c 'if True:
        import modsquad as m
        columns = set(m.parse_columns("'"$1"'"))
        for row in m.tsv_input():
            left = []
            right = []
            for i in range(len(row)):
                if i in columns:
                    right.append(row[i])
                else:
                    left.append(row[i])
            print "\t".join(left + right)
    '
}

round() {
    python2.7 -c 'if True:
        import modsquad as m, sys
        places = '"$1"'
        columns = m.parse_columns("'"$2"'")
        for row in m.tsv_input():
            for c in columns:
                row[c] = str(round(float(row[c].replace(",", "")), places))
            print "\t".join(row)
    '
}

sumby() {
    python2.7 -c 'if True:
        import collections as co, modsquad as m
        key = '"$1"' - 1
        column = '"$2"' - 1
        sums = co.OrderedDict()
        for row in m.tsv_input():
            if row[key] not in sums:
                sums[row[key]] = 0
            sums[row[key]] += float(row[column])
        for key in sums:
            print key + "\t" + str(sums[key])
    '
}
