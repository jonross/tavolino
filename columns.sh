
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
