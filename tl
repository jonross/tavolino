#!/usr/bin/python
#
# Keeping everything in memory and running each step as a separate pass over an
# array is less than efficient, but I haven't had a compelling need for
# anything more elaborate.  If that arises, add multiprocessing, and have
# ts.rows iterate over the output from the prior step.

from collections import deque
from datetime import date, datetime, time
import locale
import re
import sys

####################################################################################################

PSQL_GUTTER = re.compile(r"(\t|    )\| \S")
PSQL_SEPARATOR = re.compile(r"\s+\| ")
WHITESPACE = re.compile(r"\s+")
INTEGER = re.compile("^\d+$")
RANGE = re.compile("^(\d+)-(\d*)$")
RANGES = re.compile("^[0-9-]+(,[0-9-]+)*$")
DATE_YYYYMMDD = re.compile("^(\d\d\d\d)-(\d\d)-(\d\d)$")

locale.setlocale(locale.LC_ALL, "")

if locale.format("%.2f", 1.0) == "1,00":
    NUMCOMMA = "."
    NUMDOT = ","
else:
    NUMCOMMA = ","
    NUMDOT = "."

SEPARATOR_NAMES = {
    "csv" : ",",
    "psv" : "|",
    "ssv" : " ",
    "tsv" : "\t"
    }

####################################################################################################

def main(args):

    """
    Main driver:
     * Call argument parser
     * Figure out how to split and rejoin lines
     * Split the input
     * Normalize row width
     * Run each step
     * Rejoin and output
    """

    ts = TState()
    steps = parse_args(ts, args)

    lines = [line.strip() for line in sys.stdin]
    if len(lines) == 0:
        sys.exit(0)

    if ts.ifs == " ":
        splitter = WHITESPACE.split
    elif ts.ifs is not None:
        splitter = lambda line: line.split(ts.ifs)
    else:
        splitter, ofs = guess_separators(lines[:10])
        # Use best guess for OFS if it wasn't set
        if ts.ofs is None:
            ts.ofs = ofs

    ts.rows = [splitter(line) for line in lines]
    widest = max(len(row) for row in ts.rows)

    # Widen rows to max width

    def normalize(row):
        if len(row) < widest:
            # TODO: change this to [None]
            return row + [""] * (widest - len(row))
        return row

    ts.rows = map(normalize, ts.rows)

    # For each step make ts.rows the output of the previous step

    for step in steps:
        step(ts)
        ts.rows = ts.output
        ts.output = []

    if not ts.suppress:
        for row in ts.rows:
            print ts.ofs.join(map(str, row))

def parse_args(ts, args):

    """
    Parse the argument queue, make changes to TState, and return a transformation function for 
    each step that operates on input rows.
    """

    steps = []

    def add_step(function, *arg_info):

        parsed_args = [parse_arg(args, a[0], a[1]) for a in arg_info]
        steps.append(lambda ts: function(ts, *parsed_args))

    while len(args) > 0:

        arg = args.popleft()
        nextarg = args[0] if len(args) > 0 else None

        # This parsing is best understood by reading the step documentation.
        #
        # I could also do this with fancy decorators on each step function, but a simple 
        # if statement is easier to follow.

        if arg in SEPARATOR_NAMES:
            ts.ifs = SEPARATOR_NAMES[arg]
            ts.ofs = SEPARATOR_NAMES[arg]

        elif arg == "to" and nextarg in SEPARATOR_NAMES:
            ts.ofs = SEPARATOR_NAMES[nextarg]
            args.popleft()

        elif RANGES.match(arg):
            args.appendleft(arg)
            args.appendleft("keep")

        elif arg == "cum":
            add_step(calc_sum, ("column expression", ColumnList.from_string))

        elif arg == "delta":
            add_step(calc_delta, ("column expression", ColumnList.from_string))

        elif arg == "drop":
            add_step(drop_columns, ("column expression", ColumnList.from_string))

        elif arg == "dup":
            add_step(duplicate_columns, ("column expression", ColumnList.from_string))

        elif arg == "ema":
            add_step(calc_ema, ("EMA period", silent(int)), ("column expression", ColumnList.from_string))

        elif arg == "keep":
            add_step(keep_columns, ("column expression", ColumnList.from_string))

        elif arg == "neat":
            add_step(neaten_output)

        elif arg == "ord":
            add_step(prepend_ordinal)

        elif arg == "per":
            add_step(calc_percent, ("column expression", ColumnList.from_string))

        elif arg == "redate":
            # TODO: tests
            add_step(reformat_date, ("date format", str), ("column expression", ColumnList.from_string))

        elif arg == "round":
            add_step(calc_round, ("# of places", silent(int)), ("column expression", ColumnList.from_string))

        elif arg == "set":
            add_step(set_column, ("cN=EXPRESSION", re.compile("^c(\d+)=(.+)").match))

        elif arg == "wiki":
            add_step(wikify_output)

        else:
            die("Unknown step: " + arg)

    return steps

def parse_arg(args, description, converter):

    """
    Handle parsing of one arg; pop it off the queue and pass it to the conversion function.
    Die if the queue is empty or the converter returns None or raises an exception.
    """

    if len(args) == 0:
        die("Missing argument, expected " + description)

    arg = args.popleft()
    value = converter(arg)

    if value is None:
        die ("Expected " + description + " but got " + arg)

    return value

####################################################################################################

class TState:

    """
    Global mutable state.
    """

    def __init__(self):

        # Input field separator
        self.ifs = None

        # Output field separator
        self.ofs = None

        # Input lines, split into fields
        self.rows = []

        # Output rows for each step; becomes self.rows for the next step
        self.output = []

        # Suppress final output (if a step has done custom output)
        self.suppress = False

    def write(self, row):
        self.output.append(row)

class ColumnList:

    """
    Represents a list of columns indexed, possibly with unbounded end points,
    e.g. 1-3,5,8-
    When returned to callers these are zero-based for use in lists.
    """

    def __init__(self, ranges):

        """
        For the above example, this would contain
          [(1, 3), (5, 5), (8, 1000)]
        """

        self.ranges = ranges

    @classmethod
    def from_string(cls, s):

        ranges = []
        for part in s.replace("c", "").split(","):

            if INTEGER.match(part):
                index = int(part)
                if index < 1:
                    die("Invalid column index " + part)
                ranges.append((index, index))

            elif RANGE.match(part):
                start, end = part.split("-")
                if end != "":
                    start, end = int(start), int(end)
                    if start < 1 or end < 1 or start > end:
                        die("Invalid column range: " + part)
                    ranges.append((start, end))
                else:
                    start = int(start)
                    ranges.append((start, 1000))

            else:
                die("Invalid column: " + part)

        return ColumnList(ranges)

    def indices(self, width):

        """
        Return an actual list of indices in the original order, but no more than the the given
        row width.  For the above exaple this would be [0, 1, 2, 4, 7, 8, ...]
        """

        ix = []
        for r in self.ranges:
            for i in range(r[0], min(r[1], width) + 1):
                ix.append(i - 1)
        return ix

    def flags(self, width):

        """
        Return the indices as an array of boolean flags, but no more than the given row width.
        For the above example this would be [T, T, T, F, T, F, F, T, T, ...]
        """

        ix = [False] * width
        for r in self.ranges:
            for i in range(r[0], min(r[1], width) + 1):
                ix[i - 1] = True
        return ix

####################################################################################################

def guess_separators(lines):

    """
    Given a sample of lines, try to determine the input field separator.  Return a
    splitting function and the best output separator.
    """

    def splitter(sep):
        return lambda s: s.split(sep)

    if len(lines) == 0:
        return WHITESPACE.split, "\t"

    if all(PSQL_GUTTER.search(line) for line in lines):
        return PSQL_SEPARATOR.split, "\t"

    def allsame(array):
        return array[0] > 0 and all(map(lambda n: n == array[0], array))

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
        return int, lambda x: convert(x, locale.atoi)
    elif all(type(x) in [float, int] for x in column):
        return float, lambda x: convert(x, locale.atof)
    elif all(type(x) == date for x in column):
        # TODO: handle multiple date input formats
        return date, lambda x: x.strptimetime("%Y-%m-%d")
    else:
        return str, str

def convert(value, bias=None):

    """
    Intuit the type of a value and convert it.  
    
    Anything not a string is returned unchanged; otherwise we try the bias function if
    specified; otherwise try ints, floats, and some date formats.  Commas are stripped
    before numeric parsing.
    """

    if value is None:
        return None

    if type(value) != str:
        return value

    svalue = strip_commas(value)
    if bias is not None:
        try:
            return bias(svalue)
        except:
            return value

    try:
        return locale.atoi(svalue)
    except:
        try:
            return locale.atof(svalue)
        except:
            pass

    m = DATE_YYYYMMDD.match(value)
    if m:
        # TODO: handle multiple date input formats
        return date(int(m.group(1)), int(m.group(2)), int(m.group(3)))

    return value


def make_format(typ, comma=False):

    """
    Return a formatting function for the indicated type.
    Numerics will have commas unless overridden.
    """

    if typ == float:
        return "{:,.2f}".format if comma else "{:.2f}".format
    elif typ == int:
        return "{:,}".format if comma else str
    else:
        # TODO: date formatter needed here?
        return str

####################################################################################################

def calc_delta(ts, colist):

    """
    Insert a running delta for each tagged column in colist.
    """

    rows = list(ts.rows)
    flags = colist.flags(len(rows[0]))

    offset = 0
    for index in range(0, len(rows[0])):
        if flags[index]:
            last = None
            for row in rows:
                value = convert(row[index + offset])
                delta = 0 if last is None else value - last
                last = value
                row.insert(index + offset + 1, delta)
            offset += 1

    for row in rows:
        ts.write(row)

def calc_ema(ts, k, colist):

    """
    Insert a running exponential moving average for each tagged column in colist.
    """

    rows = list(ts.rows)
    flags = colist.flags(len(rows[0]))

    offset = 0
    for index in range(0, len(rows[0])):
        if flags[index]:
            last = None
            for row in rows:
                cell = convert(row[index], locale.atof)
                if type(cell) == float:
                    value = cell if last is None else ((k - 1) * last + cell) / k
                else:
                    value = cell if last is None else last
                row.insert(index + offset + 1, value)
                last = value
            offset += 1

    for row in rows:
        ts.write(row)

def calc_percent(ts, colist):

    """
    For each column in colist, calculate and insert its percent of the total value
    for that column.
    """

    rows = list(ts.rows)
    flags = colist.flags(len(rows[0]))

    offset = 0
    for index in range(0, len(rows[0])):
        if flags[index]:
            values = [float(row[index + offset]) for row in rows]
            total = sum(values)
            if total > 0:
                percents = [value / total * 100 for value in values]
            else:
                percents = [0 for value in values]
            for row, percent in zip(rows, percents):
                row.insert(index + offset + 1, percent)
            offset += 1

    for row in rows:
        ts.write(row)

def calc_round(ts, places, colist):

    """
    For each column in colist, round its values to N places.
    """

    rows = list(ts.rows)
    flags = colist.flags(len(rows[0]))

    for index in range(0, len(rows[0])):
        if flags[index]:
            for row in rows:
                value = convert(row[index], locale.atof)
                if type(value) == float:
                    row[index] = round(value, places)

    for row in rows:
        ts.write(row)

def calc_sum(ts, colist):

    """
    Insert a running sum for each tagged column in colist.
    """

    rows = list(ts.rows)
    flags = colist.flags(len(rows[0]))

    offset = 0
    for index in range(0, len(rows[0])):
        if flags[index]:
            cum = 0
            for row in rows:
                cum += convert(row[index + offset])
                row.insert(index + offset + 1, cum)
            offset += 1

    for row in rows:
        ts.write(row)

def duplicate_columns(ts, colist):

    """
    Insert a duplicate of the tagged columns in colist.
    """

    rows = list(ts.rows)
    flags = colist.flags(len(rows[0]))

    offset = 0
    for index in range(0, len(rows[0])):
        if flags[index]:
            for row in rows:
                row.insert(index + offset + 1, row[index + offset])
            offset += 1

    for row in rows:
        ts.write(row)

def drop_columns(ts, colist):

    """
    For each line of input, drop the columns where flags[index] is True.
    Lines with all columns removed are deleted; they don't generate an empty line.
    """

    rows = list(ts.rows)
    flags = colist.flags(len(rows[0]))

    for row in ts.rows:
        newrow = []
        for index, item in enumerate(row):
            if not flags[index]:
                newrow.append(item)
        if len(newrow) > 0:
            ts.write(newrow)

def keep_columns(ts, colist):

    """
    For each line of input, keep the columns where flags[index] is True.
    Lines with all columns removed are deleted; they don't generate an empty line.
    Note, this is not simply the opposite of drop_columns, since the order may be changed
    e.g.: keep 3,2,1
    """

    rows = list(ts.rows)
    indices = colist.indices(len(rows[0]))

    for row in rows:
        newrow = []
        for index in colist.indices(len(row)):
            newrow.append(row[index])
        if len(newrow) > 0:
            ts.write(newrow)

def neaten_output(ts):

    """
    Generate easily readable text output.
    Try to guess column types to improve formatting.
    This can only be the final step in the list.
    """

    rows = list(ts.rows)
    columns = transpose(rows[:20])
    ts.suppress = True
    types = []

    # Guess column types and format the data.
    # Then pad each column to match the widest value in that column.

    for index, column in enumerate(columns):

        typ, converter = guess_type(column)
        types.append(typ)
        formatter = make_format(typ, True)
        if typ in [int, float]:
            for row in rows:
                row[index] = formatter(converter(row[index]))

        span = max(len(row[index]) for row in rows)
        spacer = str.rjust if types[index] in [int, float] else str.ljust
        for row in rows:
            row[index] = spacer(row[index], span)

    for row in rows:
        print "  ".join(row)

def prepend_ordinal(ts):

    """
    Add an ordinal value (1-based) to the beginning of every line.
    """

    lineno = 1
    for row in ts.rows:
        row.insert(0, lineno)
        ts.write(row)
        lineno += 1

def reformat_date(ts, dateformat, colist):

    # TODO: comment

    rows = list(ts.rows)
    sample = transpose(rows[:20])
    columns = colist.indices(len(rows[0]))
    formatter = lambda d: d.strftime(dateformat)

    for index in columns:
        typ, converter = guess_type(sample[index])
        if typ == int:
            for row in rows:
                row[index] = formatter(datetime.fromtimestamp(int(row[index])))
        elif typ == date:
            for row in rows:
                row[index] = formatter(converter(row[index]))
        else:
            die("Can't convert column %d to dates" % index)

    for row in rows:
        ts.write(row)

def set_column(ts, cmatch):

    """
    Set the value of a column to the result of an expression, where e.g. cN = row[N-1].
    cmatch has already matched the column # and replacement.
    """

    rows = list(ts.rows)
    target = int(cmatch.group(1)) - 1
    expr = cmatch.group(2)
    setbody = re.sub("c(\d+)", lambda m: "row[%d]" % int(m.group(1))-1, expr)
    setter = eval("lambda row: " + setbody)

    for row in rows:
        row[target] = setter(row)
        ts.write(row)

def wikify_output(ts):

    """
    Generate output suitable for Twiki or Confluence.
    Try to guess column types to improve formatting.
    This can only be the final step in the list.
    """

    rows = list(ts.rows)
    columns = transpose(rows[:20])
    ts.suppress = True

    for index, column in enumerate(columns):
        typ, converter = guess_type(column)
        formatter = make_format(typ, True)
        if typ in [int, float]:
            # provide leading space to right-justify numbers
            for row in rows:
                row[index] = " " + formatter(converter(row[index]))

    for row in rows:
        print "| " + " | ".join(row) + " |"

####################################################################################################

def die(message):
    warn(message)
    sys.exit(1)

def silent(f):
    def wrapped(*args):
        try:
            return f(*args)
        except:
            return None
    return wrapped

def strip_commas(value):
    return value.translate(None, NUMCOMMA) if NUMCOMMA in value else value

def transpose(rows):
    if len(rows) == 0:
        return rows
    return [[rows[n][i] for n in range(len(rows))] for i in range(len(rows[0]))]

def warn(message):
    sys.stderr.write(message + "\n")

####################################################################################################

main(deque(sys.argv[1:]))

