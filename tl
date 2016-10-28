#!/usr/bin/python

from collections import namedtuple
from datetime import date, datetime, time
from itertools import chain, imap, izip, ifilter, tee
import locale
import operator as op
import re
import sys

####################################################################################################

# Matches any run of whitespace
WHITESPACE = re.compile(r"\s+")
# Matches a string containing only an integer, with no whitespace
INTEGER = re.compile("^\d+$")
# Matches e.g. "1-3" or "8-"
RANGE = re.compile("^(\d+)-(\d*)$")
# Matches e.g. "1-3,5,8-"
RANGES = re.compile("^[0-9-]+(,[0-9-]+)*$")
# How to recognize a date a la 2015-04-01
DATE_YYYYMMDD = re.compile("^(\d\d\d\d)-(\d\d)-(\d\d)$")

# Command-line synonyms for common field separators
SEPARATOR_NAMES = { "csv" : ",", "psv" : "|", "ssv" : " ", "tsv" : "\t" }

# Holds information from the command line other than step functions
Options = namedtuple("Options", "split_on join_on")

# A type conversion indicator that means either int or float
NUMERIC = object()

# Are numbers like "1,000.00" or "1.000,00"
locale.setlocale(locale.LC_ALL, "")
if locale.format("%.2f", 1.0) == "1,00":
    NUMCOMMA, NUMDOT = ".", ","
else:
    NUMCOMMA, NUMDOT = ",", "."

####################################################################################################

def main(argv):

    steps, options = parse_argv(argv)
    lines = map(str.strip, sys.stdin)
    if len(lines) == 0:
        sys.exit(0)

    # Determine how to split lines; default for joining them is how we split them...

    if options.split_on == " ":
        splitter = WHITESPACE.split
        join_on = " "
    elif options.split_on is not None:
        splitter = lambda line: line.split(options.split_on)
        join_on = options.split_on
    else:
        splitter, join_on = guess_separators(lines[:10])

    # ... unless were were told how to join them.

    if options.join_on is not None:
        join_on = options.join_on

    # Split to rows then widen to max width.

    rows = map(splitter, lines)
    widest = max(map(len, rows))

    def normalize(row):
        if len(row) < widest:
            # TODO: change this to [None]
            return row + [None] * (widest - len(row))
        return row

    rows = map(normalize, rows)

    # Transpose to columns & run steps, then back to rows for output.

    table = Table(zip(*rows))
    for step in steps:
        step(table)

    if table.columns and not table.suppress:
        for row in izip(*table.columns):
            print join_on.join(map(lambda x: "" if x is None else str(x), row))

####################################################################################################

class Table:

    def __init__(self, columns):
        self.columns = columns
        self.width = len(columns)
        # Suppress final output (if a step has done custom output)
        self.suppress = False

    def insert_columns(self, newcols, indices, after=True):
        """Insert each column in newcols before / after its corresponding index in a sorted index list"""
        offsets = range(1, len(indices)+1) if after else range(len(indices))
        for newcol, index in izip(newcols, map(op.add, indices, offsets)):
            self.columns.insert(index, newcol)

    def calc_columns(self, colist, mapper, bias=None):
        """Like insert_columns but works by mapping a function over an existing column set."""
        indices = colist.uniques(self.width)
        inputs = [[convert(value, bias) for value in self.columns[i]] for i in indices]
        self.insert_columns([mapper(column) for column in inputs], indices)

    def map_columns(self, colist, mapper, bias=None):
        """Like calc_columns but overwrites the target columns."""
        for i in colist.uniques(self.width):
            self.columns[i] = mapper([convert(value, bias) for value in self.columns[i]])

class ColumnList:

    """
    Represents a list of columns indexed, possibly with unbounded end points,
    e.g. 1-3,5,8-
    When returned to callers these are zero-based for use in lists.
    """

    def __init__(self, ranges):
        """ For the above example, this would contain [(1, 3), (5, 5), (8, 1000)]"""
        self.ranges = ranges

    @classmethod
    def from_string(cls, s):
        def _parse(part):
            if INTEGER.match(part):
                index = int(part)
                if index < 1:
                    die("Invalid column index " + part)
                return (index, index)
            if RANGE.match(part):
                start, end = part.split("-")
                start, end = int(start), int(end if end != "" else 1000)
                if start < 1 or end < 1 or start > end:
                    die("Invalid column range: " + part)
                return (start, end)
            die("Invalid column: " + part)
        return ColumnList([_parse(part) for part in s.replace("c", "").split(",")])

    def indices(self, width):

        """
        Return an actual list of indices in the original order, but no more than the the given
        row width.  For the above exaple this would be [0, 1, 2, 4, 7, 8, ...]
        """

        def zerobase(r, width):
            return range(r[0], min(r[1], width) + 1)
        return map(lambda x: x - 1, reduce(op.add, [zerobase(r, width) for r in self.ranges]))

    def uniques(self, width):
        """Same as indices() but sorted and unique."""
        return sorted(set(self.indices(width)))

    def flags(self, width):
        """Return the indices as an array of boolean flags, but no more than the given row width.
        For the above example this would be [T, T, T, F, T, F, F, T, T, ...]"""
        uniques = self.uniques(width)
        return map(lambda index: index in uniques, range(width))

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
    "cum":      [("column expression", ColumnList.from_string)],
    "delta":    [("column expression", ColumnList.from_string)],
    "drop":     [("column expression", ColumnList.from_string)],
    "dup":      [("column expression", ColumnList.from_string)],
    "ema":      [("column expression", ColumnList.from_string), 
                 ("EMA period", silent(int))],
    "keep":     [("column expression", ColumnList.from_string)],
    "neat":     [],
    "ord":      [],
    "per":      [("column expression", ColumnList.from_string)],
    "redate":   [("column expression", ColumnList.from_string), 
                 ("date format", str)],
    "round":    [("column expression", ColumnList.from_string),
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
        step_fn = eval(arg + "_step")
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

def delta_step(table, colist):
    """Insert a running delta for each tagged column in colist."""
    def deltas(column):
        first = 0 if column[0] is None else column[0]
        filled = ((b if b is not None else a) for a, b in with_prev(column, first))
        return [b - a for a, b in with_prev(filled, first)]
    table.calc_columns(colist, deltas)

def ema_step(table, colist, k):
    """Insert a running exponential moving average for each tagged column in colist."""
    def ema(prev, curr):
        return prev if curr is None else ((k - 1) * prev + curr) * 1.0 / k
    table.calc_columns(colist, lambda column: remap(ema, column))

def per_step(table, colist):
    """For each column in colist, calculate and insert its percent of the total value for that column."""
    def percent(column):
        total = sum(filter(notnone, column))
        if total > 0:
            return [(0 if item is None else (item * 1.0 / total * 100)) for item in column]
        else:
            return [0 for item in column]
    table.calc_columns(colist, percent)

def round_step(table, colist, places):
    """For each column in colist, round its values to N places."""
    def doround(column):
        return map(lambda value: round(float(value), places), column)
    table.map_columns(colist, doround)

def cum_step(table, colist):
    """Insert a running sum for each tagged column in colist."""
    table.calc_columns(colist, lambda column: remap(op.add, column, 0))

def dup_step(table, colist):
    """Insert a duplicate of the tagged columns in colist."""
    table.calc_columns(colist, lambda column: column[:])

def drop_step(table, colist):
    """Remove the designated columns."""
    flags = colist.flags(table.width)
    table.columns = [column for i, column in enumerate(table.columns) if not flags[i]]

def keep_step(table, colist):
    """Remove all but the designated columns.  Note, this is not simply the opposite of 
    drop_columns, since the order may be changed e.g.: keep 3,2,1
    """
    indices = colist.indices(table.width)
    table.columns = [table.columns[i][:] for i in indices]

def neat_step(table):
    """Generate easily readable text output.  Try to guess column types to improve formatting.
    This can only be the final step in the list.
    """

    def neaten(column):
        kind, converter = guess_type(column[:20])
        if kind in [int, float]:
            formatter = make_format(kind, True)
            column = map(lambda cell: formatter(converter(cell)), column)
            spacer = str.rjust
        else:
            spacer = str.ljust
        maxwidth = max(map(len, column))
        return [spacer(item, maxwidth) for item in column]

    table.suppress = True
    for row in izip(*map(neaten, table.columns)):
        print "  ".join(row)

def ord_step(table):
    """Add an ordinal value (1-based) to the beginning of every line."""
    numbers = range(1, len(table.columns[0])+1)
    table.insert_columns([numbers], [0], False)
    
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

def wiki_step(table):

    """
    Generate output suitable for Twiki or Confluence.
    Try to guess column types to improve formatting.
    This can only be the final step in the list.
    """

    def neaten(column):
        kind, converter = guess_type(column[:20])
        if kind in [int, float]:
            formatter = make_format(kind, True)
            # provide leading space to right-justify numbers
            return [" " + formatter(converter(item)) for item in column]
        return column

    table.suppress = True
    for row in izip(*map(neaten, table.columns)):
        print "| " + " | ".join(row) + " |"

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

def guess_type(column):

    """
    Given a sample of column values, try to guess the type; return the type class and a
    default conversion function.
    """

    if len(column) == 0:
        return str, str

    column = map(convert, column)
    if all(type(x) == int for x in column):
        return int, lambda x: convert(x, [locale.atoi])
    elif all(type(x) in [float, int] for x in column):
        return float, lambda x: convert(x, [locale.atof])
    elif all(type(x) == date for x in column):
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

def notnone(x):
    return x is not None

def coalesce(seq):
    return next(ifilter(notnone, iter(seq)), None)

def pairwise(seq):
    a, b = tee(seq)
    next(b, None)
    return izip(a, b)

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

