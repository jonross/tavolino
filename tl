#!/usr/bin/env python3

from collections import namedtuple
from datetime import date, datetime, time
from itertools import chain, tee
import json
import locale
import operator as op
import re
import sys

####################################################################################################

# Match any run of whitespace
WHITESPACE = re.compile(r"\s+")
# Match a string containing only an integer, with no whitespace
INTEGER = re.compile("^\d+$")
# Match e.g. "1-3" or "8-"
RANGE = re.compile("^(\d+)-(\d*)$")
# Match e.g. "1-3,5,8-"
RANGES = re.compile("^[0-9-]+(,[0-9-]+)*$")
# Match a date in YYYY-MM-DD format
DATE_YYYYMMDD = re.compile("^(\d\d\d\d)-(\d\d)-(\d\d)$")

# Command-line synonyms for common field separators
SEPARATOR_NAMES = { "csv" : ",", "psv" : "|", "ssv" : " ", "tsv" : "\t" }

# Holds information from the command line other than step functions
Options = namedtuple("Options", "split_on join_on")

# Are numbers like "1,000.00" or "1.000,00"
locale.setlocale(locale.LC_ALL, "")
if locale.format_string("%.2f", 1.0) == "1,00":
    NUMCOMMA, NUMDOT = ".", ","
else:
    NUMCOMMA, NUMDOT = ",", "."

####################################################################################################

def main(argv):

    steps, options = parse_argv(argv)
    lines = [line.strip() for line in sys.stdin]
    if len(lines) == 0:
        sys.exit(0)

    # Determine how to split lines.  The default for joining them is how we split them, unless
    # we were told how to join them.

    if options.split_on == " ":
        splitter = WHITESPACE.split
        join_on = " "
    elif options.split_on is not None:
        splitter = lambda line: line.split(options.split_on)
        join_on = options.split_on
    else:
        splitter, join_on = guess_separators(lines[:10])

    if options.join_on is not None:
        join_on = options.join_on

    # Split to rows then widen to max width.

    rows = [splitter(line) for line in lines]
    widest = max(len(row) for row in rows)
    normalize = lambda row: row if len(row) == widest else row + [None] * (widest - len(row))
    rows = [normalize(row) for row in rows]

    # Transpose to columns & run steps, then back to rows for output.

    table = Table(list(c) for c in zip(*rows))
    for step in steps:
        step(table)

    if table.columns and not table.suppress:
        for row in zip(*(column.data for column in table.columns)):
            print(join_on.join(to_str(cell) for cell in row))

####################################################################################################

class Targets:

    """Designates columns to affect.  Parsed from a string like "c1-3,5,8-", which has "explicit"
    columns c1,c2,c3,c5,c8 (which must exist in the table) and "implicit" columns c9 onward, which
    are optional."""

    def __init__(self, explicit, implicit):
        self.explicit = explicit
        self.implicit = implicit

    @classmethod
    def parse(cls, s):
        def _parse(part):
            # Match e.g. "c5"
            if INTEGER.match(part):
                index = int(part)
                if index < 1:
                    die("Invalid column index " + part)
                return (["c%d" % index], None)
            # Match e.g. "c1-3" or "c8-"
            if RANGE.match(part):
                start, end = part.split("-")
                start, end = int(start), int(end if end != "" else 10000)
                if start < 1 or end < 1 or start > end:
                    die("Invalid column range: " + part)
                if end == 10000:
                    return (["c%d" % start], start + 1)
                return (["c%d" % i for i in range(start, end + 1)], None)
            die("Invalid column: " + part)
        explicit, implicit = [], None
        for ex, im in (_parse(part) for part in s.replace("c", "").split(",")):
            explicit += ex
            if implicit is None or im is not None:
                implicit = im
        return Targets(explicit, implicit)

    def __str__(self):
        return f"explicit={self.explicit}, implicit={self.implicit}"

class Column:

    """A Table, below, is made up of these (obviously)"""

    def __init__(self, data):
        # Array of column values
        self.data = data
        # User-addressible name like "c3" or "Sales"
        self.name = None
        # Column has an automatic name like "c3", not user-defined like "Sales"
        self.auto = True

    def clone(self):
        return Column(self.data[:])

    @classmethod
    def of(cls, thing):
        return cls(thing) if isinstance(thing, list) else thing
    
class Table:

    """A set of Columns, above (obviously)"""

    def __init__(self, columns):
        self.columns = [Column.of(c) for c in columns]
        # Column count
        self.width = None
        # Suppress final output (if a step has done custom output)
        self.suppress = False
        # Call this after every modification to .columns
        self.reset()

    def reset(self):
        self.width = len(self.columns)
        for index, column in enumerate(self.columns):
            if column.auto:
                column.name = "c%d" % (index + 1)

    def select(self, targets):
        result = [self.get_named(name) for name in targets.explicit]
        if targets.implicit:
            result += [self.columns[i] for i in range(targets.implicit - 1, self.width)]
        return result
        
    def get_named(self, name):
        index = self.index_of(name)
        if index is not None:
            return self.columns[index]
        raise ValueError("No column named " + name)

    def index_of(self, thing):
        for index, column in enumerate(self.columns):
            if type(thing) == str and column.name == thing:
                return index
            if thing == column:
                return index
        return None

    def insert_after(self, column, new_column):
        self.columns.insert(1 + self.index_of(column), Column.of(new_column))
        self.reset()

    def derive(self, targets, function, overwrite=False):
        """For each of the named columns, calculate a new column by applying the function to its
        values.  Optionally overwrite the existing column."""
        insert = self.replace_with if overwrite else self.insert_after
        for column in self.select(targets):
            insert(column, function([convert(item) for item in column.data]))

    def replace_with(self, column, new_column):
        self.columns[self.index_of(column)] = Column.of(new_column)
        self.reset()

####################################################################################################

# A dict describing how to parse options for step names.
# Keys are step names, and the values are an array of tuples, one per arg, with each tuple
# containing a description of the arg, and a function to parse it (returning None on failure.)

def silent(f):
    def wrapped(*args):
        try:
            return f(*args)
        except:
            return None
    return wrapped

ARG_SPECS = {
    "cum":      [("column expression", Targets.parse)],
    "delta":    [("column expression", Targets.parse)],
    "drop":     [("column expression", Targets.parse)],
    "dup":      [("column expression", Targets.parse)],
    "ema":      [("column expression", Targets.parse), 
                 ("EMA period", silent(int))],
    "keep":     [("column expression", Targets.parse)],
    "neat":     [],
    "ord":      [],
    "per":      [("column expression", Targets.parse)],
    "redate":   [("column expression", Targets.parse), 
                 ("date format", str)],
    "round":    [("column expression", Targets.parse),
                 ("# of places", silent(int))],
    "set":      [("cN=EXPRESSION", re.compile("^c(\d+)=(.+)").match)],
    "wiki":     []
}

def parse_argv(argv, steps=[], options=Options(None, None)):
    """Parse command line, returning a list of transformation steps and additional options."""

    if len(argv) == 0:
        return steps, options

    arg, argv = argv[0], argv[1:]
    nextarg = argv[0] if len(argv) > 0 else None

    if arg in SEPARATOR_NAMES:
        options = options._replace(split_on=SEPARATOR_NAMES[arg], join_on=SEPARATOR_NAMES[arg])

    elif arg == "to" and nextarg in SEPARATOR_NAMES:
        options = options._replace(join_on=SEPARATOR_NAMES[nextarg])
        argv = argv[1:]

    elif RANGES.match(arg):
        argv = ["keep", arg] + argv

    else:
        specs = ARG_SPECS.get(arg)
        if specs is None:
            die("Unknown step: " + arg)
        step_fn = eval("do_" + arg)
        step_args = []
        for description, converter in specs:
            if len(argv) == 0:
                die("Missing argument, expected " + description)
            arg, argv = argv[0], argv[1:]
            value = converter(arg)
            if value is None:
                die ("Expected " + description + " but got " + arg)
            step_args.append(value)
        steps.append(lambda table: step_fn(table, *step_args))

    return parse_argv(argv, steps, options)

####################################################################################################

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
        total = sum(filter(not_none, data))
        if total > 0:
            return [(0 if item is None else (item * 1.0 / total * 100)) for item in data]
        else:
            return [0 for item in data]
    table.derive(targets, percent)

def do_round(table, names, places):
    rounder = lambda seq: [round(float(item), places) for item in seq]
    table.derive(names, rounder, True)

def do_cum(table, targets):
    table.derive(targets, lambda data: list(remap(op.add, data, 0)))

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
            data = [formatter(converter(cell)) for cell in column.data]
            spacer = str.rjust
        else:
            spacer = str.ljust
            data = column.data
        maxwidth = max(len(cell) for cell in data)
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

####################################################################################################

def to_int(value):
    """Coerce a value to int, if possible, else return None"""
    if type(value) == str:
        if NUMCOMMA in value:
            value = value.translate(None, NUMCOMMA)
    try:
        return int(value)
    except:
        return None

def to_float(value):
    """Coerce a value to float, if possible, else return None"""
    if type(value) == str:
        if NUMCOMMA in value:
            value = value.translate(None, NUMCOMMA)
    try:
        return float(value)
    except:
        return None

NUMERIC_CONVERTERS = [to_int, to_float]

def convert(value, using=None):
    """Coerce a value using one of the listed functions (default to_int then to_float)"""
    if using is None:
        using = NUMERIC_CONVERTERS
    return coalesce(f(value) for f in using)

def guess_separators(lines):

    """
    Given a sample of lines, try to determine the input field separator.  Return a
    splitting function and the best output separator.
    """

    def splitter(sep):
        return lambda s: s.split(sep)

    if len(lines) == 0:
        return WHITESPACE.split, "\t"

    def allsame(array):
        return array[0] > 0 and all(n == array[0] for n in array)

    for sep in ["|", "\t", ","]:
        if allsame([line.count(sep) for line in lines]):
            return splitter(sep), sep

    return WHITESPACE.split, "\t"

def guess_type(sample):

    """
    Given a sample of column values, try to guess the type; return the type class and a
    default conversion function.
    """

    if len(sample) == 0:
        return str, str

    sample = map(convert, sample)
    if all(type(x) == int for x in sample):
        return int, lambda x: convert(x, [locale.atoi])
    elif all(type(x) in [float, int] for x in sample):
        return float, lambda x: convert(x, [locale.atof])
    elif all(type(x) == date for x in sample):
        # TODO: handle multiple date input formats
        return date, lambda x: x.strptimetime("%Y-%m-%d")
    else:
        return str, str

def to_date(value):
    m = DATE_YYYYMMDD.match(value)
    if m:
        # TODO: handle multiple date input formats
        return date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    return None

def make_format(typ, comma=False):
    """Return a formatting function for a type; numerics will have commas unless overridden."""
    if typ == float:
        return "{:,.2f}".format if comma else "{:.2f}".format
    elif typ == int:
        return "{:,}".format if comma else str
    else:
        # TODO: date formatter needed here?
        return str

####################################################################################################

def warn(message):
    sys.stderr.write(message + "\n")

def die(message):
    warn(message)
    sys.exit(1)

def not_none(x):
    return x is not None

def coalesce(seq):
    return next(filter(not_none, iter(seq)), None)

def to_str(x):
    return "" if x is None else str(x)

def pairwise(seq):
    a, b = tee(seq)
    next(b, None)
    return zip(a, b)

def with_prev(seq, first_prev=None):
    return pairwise(chain([first_prev], seq))

def remap(f, list, value=None):
    v = [list[0]] if value is None else [value]
    def f2(x):
        v[0] = f(v[0], x)
        return v[0]
    return map(f2, list)

####################################################################################################

main(sys.argv[1:])

