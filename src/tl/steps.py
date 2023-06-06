from tl.utils import *

def do_delta(table, targets):
    def deltas(data):
        first = 0 if data[0] is None else data[0]
        filled = ((b if b is not None else a) for a, b in with_prev(data, first))
        return [b - a for a, b in with_prev(filled, first)]
    table.derive(targets, deltas)

def do_ema(table, names, k):
    """Insert a running exponential moving average for each tagged column in colist."""
    def ema(prev, curr):
        return prev if curr is None else ((k - 1) * prev + curr) * 1.0 / k
    table.derive(names, lambda data: remap(ema, data))

def do_per(table, targets):
    def percent(data):
        total = sum(filter(notnone, data))
        if total > 0:
            return [(0 if item is None else (item * 1.0 / total * 100)) for item in data]
        else:
            return [0 for item in data]
    table.derive(targets, percent)

def do_round(table, names, places):
    def _round(column):
        return map(lambda value: round(float(value), places), column)
    table.derive(names, _round, True)

def do_cum(table, targets):
    table.derive(targets, lambda data: remap(op.add, data, 0))

def do_dup(table, targets):
    table.derive(targets, lambda data: Column(data[:]))

def do_drop(table, targets):
    dropped = set(table.select(targets))
    table.columns = [column for column in table.columns if column not in dropped]
    table.reset()

def do_keep(table, targets):
    """Note, this is not simply the opposite of do_drop, since the order may be changed 
    and duplicates created, e.g. keep 3,2,2,1"""
    table.columns = [column.clone() for column in table.select(targets)]
    table.reset()

def do_neat(table):
    """Generate easily readable text output.  Try to guess column types to improve formatting.
    This can only be the final step in the list.
    """

    def neaten(column):
        kind, converter = guess_type(column.data[:20])
        if kind in [int, float]:
            formatter = make_format(kind, True)
            data = map(lambda cell: formatter(converter(cell)), column.data)
            spacer = str.rjust
        else:
            spacer = str.ljust
            data = column.data
        maxwidth = max(map(len, data))
        return [spacer(item, maxwidth) for item in data]

    table.suppress = True
    for row in zip(*map(neaten, table.columns)):
        print("  ".join(row))

def do_ord(table):
    """Add an ordinal value (1-based) to the beginning of every line."""
    numbers = range(1, len(table.columns[0].data)+1)
    table.columns.insert(0, Column(numbers))
    table.reset()
    
def redate_step(table, colist, dateformat):
    # TODO: comment & test
    formatter = lambda d: d.strftime(dateformat)
    def redate(value):
        if type(value) == int:
            return formatter(datetime.fromtimestamp(value))
        if type(value) == date:
            return formatter(value)
        die("Can't treat %s as a date" % value)
    table.map_columns(colist, lambda column: map(redate, column), [to_int, to_date])

def set_step(table, cmatch):

    """
    Set the value of a column to the result of an expression, where e.g. cN = row[N-1].
    cmatch has already matched the column # and replacement.
    """

    rows = list(table.rows)
    target = int(cmatch.group(1)) - 1
    expr = cmatch.group(2)
    setbody = re.sub("c(\d+)", lambda m: "row[%d]" % int(m.group(1))-1, expr)
    setter = eval("lambda row: " + setbody)

    for row in rows:
        row[target] = setter(row)
        table.write(row)

def do_wiki(table):

    """Generate output suitable for Twiki or Confluence.  Try to guess column types to improve formatting.
    This can only be the final step in the list."""

    def neaten(column):
        kind, converter = guess_type(column.data[:20])
        if kind in [int, float]:
            formatter = make_format(kind, True)
            # provide leading space to right-justify numbers
            return [" " + formatter(converter(item)) for item in column.data]
        return column.data

    table.suppress = True
    for row in zip(*map(neaten, table.columns)):
        print("| " + " | ".join(row) + " |")

