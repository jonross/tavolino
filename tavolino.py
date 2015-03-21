
from itertools import islice
import locale
import os
import re
import sys

INTEGER = re.compile("^\d+$")
RANGE = re.compile("^(\d+)-(\d*)$")

IFS = os.environ.get("TL_IFS")
OFS = os.environ.get("TL_OFS") or "\t"

locale.setlocale(locale.LC_ALL, "")

if locale.format("%.2f", 1.0) == "1,00":
    NUMCOMMA = "."
    NUMDOT = ","
else:
    NUMCOMMA = ","
    NUMDOT = "."

def getargs(*specs):

    argv = sys.argv[1:]
    results = []
    for spec in specs:
        result, argv = spec(argv)
        results.append(result)
    return results[0] if len(results) == 1 else results

def anyarg(description):

    def handle(args):
        if not args:
            die("Missing argument, expected " + description)
        return args[0], args[1:]

    return handle

def intarg(description):

    def handle(args):
        if not args:
            die("Missing argument, expected " + description)
        value = convert(args[0], int)
        if type(value) != int:
            die("Expected " + description + " but got " + args[0])
        return value, args[1:]

    return handle

def noargs(args):

    if args:
        die("Unexpected extra argument: " + args[0])
    return None, []

def columns(aslist=False):

    def handle(args):

        if len(args) == 0:
            die("Missing argument, expected column expression")

        columns = []
        rest = None

        for part in args[0].replace("c", "").split(","):
            if INTEGER.match(part):
                column = int(part)
                if column < 1:
                    die("Invalid column: " + part)
                columns.append(column - 1)
            else:
                m = RANGE.match(part) or die("Bad column expression: " + part)
                if m.group(2) != "":
                    start, end = int(m.group(1)), int(m.group(2))
                    if start < 1 or end < 1 or start >= end:
                        die("Invalid column range: " + part)
                    columns += [x for x in range(start - 1, end)]
                elif rest is None or int(m.group(1)) - 1 < rest:
                    rest = int(m.group(1)) - 1

        if not aslist:
            columns = set(columns)
        return (columns, rest), args[1:]

    return handle

def indices(row, columns, rest):

    max = len(row)

    for index in columns:
        if index < max:
            yield index

    if rest is not None:
        for index in range(rest, max):
            yield index

def getrows(maxrows=None, nsamples=20):

    """Sample, type and split the input, returning each line as columns
    normalized to same width.
    """

    # Read the first NSAMPLES lines; guess the separator and decide whether to
    # strip the line of whitespace.

    def readtomax():
        lineno = 0
        for line in sys.stdin:
            lineno += 1
            yield line.rstrip()
            if maxrows and lineno == maxrows:
                return

    input = readtomax()
    head = list(islice(input, 0, nsamples))
    if not head:
        return

    global IFS
    if IFS is None:
        IFS = guess_separator(head)

    if IFS == " ":
        separator = None
        stripper = str.lstrip
    else:
        separator = IFS
        stripper = lambda x: x

    # Determine max columns per row and set the function used to split and
    # width-limit each line.

    if "TL_MAXCOLUMNS" in os.environ:
        maxcolumns = int(os.environ["TL_MAXCOLUMNS"])
    else:
        maxcolumns = None

    if maxcolumns is None:
        splitter = lambda s: stripper(s).split(separator)
    elif maxcolumns == 0:
        splitter = lambda s: stripper(s)
    else:
        splitter = lambda s: stripper(s).split(separator, maxcolumns - 1)

    # Determine common column count.

    rows = [splitter(line) for line in head]
    widest = max(len(row) for row in rows)

    def normalize(row):
        if len(row) < widest:
            return row + [""] * (widest - len(row))
        return row

    # Normalize sampled rows to a common width,
    # then split & normalize the remaining input.

    for row in rows:
        yield normalize(row)

    for line in input:
        yield normalize(splitter(line))

def guess_separator(lines):

    if IFS is not None:
        return IFS

    if len(lines) == 0:
        return " "

    def allsame(array):
        return array[0] > 0 and all(map(lambda n: n == array[0], array))

    for sep in ["|", "\t", ","]:
        if allsame([line.count(sep) for line in lines]):
            return sep

    return " "

def guess_type(sample):

    if len(sample) == 0:
        return str, str

    sample = map(convert, sample)
    if all(type(x) == int for x in sample):
        return int, lambda x: convert(x, locale.atoi)
    elif all(type(x) in [float, int] for x in sample):
        return float, lambda x: convert(x, locale.atof)
    else:
        return str, str

def convert(value, bias=None):

    """Intuit the type of a value and convert it.  
    
    Anything not a string is returned unchanged; otherwise we 
    try ints, floats, and (eventually) dates.
    """

    if value is None:
        return None

    typ = type(value)
    if typ != str:
        return value

    value = stripcommas(value)
    if bias is not None:
        try:
            return bias(value)
        except:
            return value

    try:
        return locale.atoi(value)
    except:
        try:
            return locale.atof(value)
        except:
            return value

def make_format(typ, comma=False):

    if typ == float:
        return "{:,.2f}".format if comma else "{:.2f}".format
    elif typ == int:
        return "{:,}".format if comma else str
    else:
        return str

####################################################################################################

def transpose(rows):
    if len(rows) == 0:
        return rows
    return [[rows[n][i] for n in range(len(rows))] for i in range(len(rows[0]))]

def output(row, ofs=None):
    print (ofs or IFS).join(map(str, row))

def stripcommas(value):
    return value.translate(None, NUMCOMMA) if NUMCOMMA in value else value

def warn(message):
    sys.stderr.write(message + "\n")

def die(message):
    warn(message)
    sys.exit(1)

