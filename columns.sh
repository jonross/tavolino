
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
