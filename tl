#!/usr/bin/python2.7
#
# TODO: stop using Columns.list, not accurate

import collections as co
from itertools import islice
import locale
from os import path
import re
import sys

INTEGER = re.compile("^\d+$")
RANGE = re.compile("^(\d+)-(\d*)$")

Step = co.namedtuple("Step", "fn name argspecs")

STEPS = {}

####################################################################################################

def main(args):

    # With no args, normalize whitespace

    if len(args) == 0:
        args = ["to", "tsv"]

    # Set aside filenames at start of args

    args = co.deque(args)
    files = []
    badcount = 0

    while len(args) > 0 and re.search(r"\.[-A-Za-z0-9_]+$", args[0]):
        filename = args.popleft()
        if path.exists(filename):
            files.append(filename)
        else:
            warn("File " + filename + " not found")
            badcount += 1

    if badcount > 0:
        sys.exit(1)

    sip = "sip" in args
    input = None
    ifs = None
    ofs = "\t"

    # Innermost input reader; handles stdin vs file list and applies line limit.

    def readinput():
        lineno = 0
        for f in (files or [sys.stdin]):
            for line in (f if type(f) == file else open(f)):
                lineno += 1
                yield line.rstrip()
                if sip and lineno == 1000:
                    return

    # Second-level input reader; splits to columns, guesses delimiters, and
    # tags with line numbers.

    def readrows(ifs):
        input = readinput()
        head = list(islice(input, 0, 10))
        if ifs is None:
            ifs = guess_ifs(head)
        if ifs == " ":
            splitter = lambda s: s.lstrip().split(None)
        else:
            splitter = lambda s: s.split(ifs)
        lineno = 1
        for line in head:
            yield lineno, splitter(line)
            lineno += 1
        for line in input:
            yield lineno, splitter(line)
            lineno += 1

    while len(args) > 0:

        word = args.popleft()
        if word == "sip":
            continue

        words = expandalias(word)
        if words:
            args.extendleft(reversed(words))
            continue

        # Handle special names for changing field separator.  Note both cases create
        # the input only once needed; this ensures that if a field separator is specified
        # before an action, it's in the input reader delimiters.

        if word in ["fs", "ifs", "ofs"]:
            if len(args) == 0:
                die("Missing field separator")
            fs = args.popleft()
            if word == "ifs":
                ifs = fs
            elif word == "ofs":
                ofs = fs
            else:
                ifs = ofs = fs
            continue

        # Find step by name and parse the args.

        step = STEPS.get(word) or die("Unknown step name: " + word)
        stepargs = parse(args, step.argspecs)
        input = step.fn((input or readrows(ifs)), *stepargs)

    for num, row in input:
        print ofs.join(map(str, row))

def guess_ifs(lines):
    """
    Guess the correct input field separator given a sample of lines.
    If the same nonzero number of tabs is present on each, use tab.
    Otherwise use the one of (whitespace, comma, pipe) that appears
    most frequently.
    """
    if len(lines) == 0:
        return " "
    def occurrences(line, sep): 
        if sep == " ":
            return line.count(" ") + line.count("\t")
        else:
            return line.count(sep)
    ntabs = [occurrences(line, "\t") for line in lines]
    if ntabs[0] > 0 and all(map(lambda n: n == ntabs[0], ntabs)):
        return "\t"
    counts = [[(occurrences(line, sep), sep) for sep in " ,|"] for line in lines]
    bests = [second(max(c, key=first)) for c in counts]
    best = first(first(co.Counter(bests).most_common(1)))
    # print >>sys.stderr, "The best separator is", best
    return best

####################################################################################################

ALIASES = [ (re.compile(alias),expansion) for alias, expansion in [
    ("^csv$", ["fs", ","]),
    ("^ht$", ["headtail"]),
    ("^neat$", ["neaten"]),
    ("^nice$", ["neat", "1-", "ofs", "  "]),
    ("^per$", ["percent"]),
    ("^psv$", ["fs", "|"]),
    ("^s[/-_=,]", lambda word: expandsub(word)),
    ("^ssv$", ["fs", " "]),
    ("^tsv$", ["fs", "\t"]),
    ]
]

def expandalias(word):
    for regexp, expansion in ALIASES:
        if regexp.match(word):
            return expansion if type(expansion) == list else expansion(word)
    return None

def expandsub(word):
    sep = word[1]
    subpat = "^s%s([^%s]*)%s([^%s]*)%s([gi0-9]*)$" % tuple([sep] * 5)
    m = re.match(subpat, word)
    if not m:
        die("Expected substitution but got " + word)
    return ["sub", m.group(1), m.group(2), m.group(3) or ""]

####################################################################################################
#
# Arg parsers

ArgSpec = co.namedtuple("ArgSpec", "function docstring optional")

def parse(argq, argspecs):
    def parseone(spec):
        if len(argq) > 0:
            return spec.function(argq.popleft())
        return None if spec.optional else die("Missing argument, expected " + spec.docstring)
    return filter(notnone, map(parseone, argspecs))

def oneof(docstring, choices):
    def parse(arg):
        return arg if arg in choices else None
    return ArgSpec(parse, docstring, false)

def colset(docstring="column expression"):
    def parse(arg):
        return Columns.from_string(arg)
    return ArgSpec(parse, docstring, False)

def cast(function, docstring):
    def parse(arg):
        try:
            return function(arg)
        except Exception as e:
            die("Expected " + docstring + " but got: " + arg + ", error was: " + str(e))
    return ArgSpec(parse, docstring, False)

def optional(spec):
    return ArgSpec(spec.function, spec.docstring, True)

####################################################################################################
#
# Step definitions

def step(name, args):
    def wrap(f):
        step = Step(f, name, args)
        STEPS[name] = step
        return f
    return wrap

@step(name="strip", args=[cast(str, "characters to remove")])
def strip(input, chars):
    for num, row in input:
        yield num, map(lambda cell: cell.translate(None, chars))

@step(name="head", args=[cast(int, "number of lines")])
def head(input, count):
    return islice(input, 0, count)

@step(name="tail", args=[cast(int, "number of lines")])
def tail(input, count):
    return co.deque(input, count)

@step(name="headtail", args=[])
def headtail(input):
    count = 0
    queue = co.deque()
    for num, row in input:
        count += 1
        if count <= 10:
            yield num, row
        else:
            if len(queue) == 10:
                queue.popleft()
            queue.append((num,  row))
    if len(queue) > 0:
        yield 0, ["--"]
        for num, row in queue:
            yield num, row

@step(name="keep", args=[colset()])
def keep(input, colset):
    for num, row in input:
        newrow = []
        for index in colset.until(len(row)):
            newrow.append(row[index])
        yield num, newrow

@step(name="drop", args=[colset()])
def drop(input, colset):
    for num, row in input:
        newrow = []
        for index in range(0, len(row)):
            if index not in colset:
                newrow.append(row[index])
        if len(newrow) > 0:
            yield num, newrow

@step(name="to", args=[])
def split(input):
    for num, row in input:
        yield num, row

@step(name="neaten", args=[colset()])
def neaten(input, colset):
    result = []
    for num, row in input:
        result.append((num, row))
    rows = map(second, result)
    maxlen = max(map(len, rows))
    for index in colset.until(maxlen):
        column = [row[index] for row in rows]
        newcolumn = reformat(column, justify=True, comma=True)
        for row, cell in zip(rows, newcolumn):
            row[index] = cell
    for num, row in result:
        yield num, row

@step(name="ord", args=[])
def inorder(input):
    for num, row in input:
        row.insert(0, num)
        yield num, row

@step(name="percent", args=[colset()])
def add_percent(input, colset):
    result = []
    for num, row in input:
        result.append((num, row))
    if not result:
        return
    rows = map(second, result)
    offset = 0
    for index in range(0, len(rows[0])):
        if index in colset:
            values = [float(row[index + offset]) for row in rows]
            total = sum(values)
            if total > 0:
                percents = [value / total * 100 for value in values]
            else:
                percents = [0 for value in values]
            for row, percent in zip(rows, percents):
                row.insert(index + offset + 1, percent)
            offset += 1
    for num, row in result:
        yield num, row

@step(name="cum", args=[colset()])
def add_cum(input, colset):
    result = []
    for num, row in input:
        result.append((num, row))
    if not result:
        return
    rows = map(second, result)
    offset = 0
    for index in range(0, len(rows[0])):
        if index in colset:
            cum = rows[0][index + offset] * 0
            for row in rows:
                cum += row[index + offset]
                row.insert(index + offset + 1, cum)
            offset += 1
    for num, row in result:
        yield num, row

@step(name="sub", args=[cast(re.compile, "pattern"), cast(str, "replacement"), cast(str, "flags"), colset()])
def substitute(input, pat, rep, flags, colset):
    count = 1
    reflags = 0
    for flag in flags:
        if flag in "0123456789":
            count = int(flag)
        elif flag == "g":
            count = 0
        elif flag == "i":
            reflags = re.I
        else:
            die("Bad regexp flag: " + flag)
    for num, row in input:
        if num > 0:
            for index in colset.until(len(row)):
                row[index] = pat.sub(rep, row[index], count)
        yield num, row

@step(name="left", args=[colset()])
def pull_left(input, colset):
    # TODO optimize for fixed length
    for num, row in input:
        left, right = [], []
        for index in range(0, len(row)):
            if index in colset:
                left.append(row[index])
            else:
                right.append(row[index])
        for row in right:
            left.append(row)
        yield num, left

@step(name="right", args=[colset()])
def pull_right(input, colset):
    # TODO optimize for fixed length
    for num, row in input:
        left, right = [], []
        for index in range(0, len(row)):
            if index in colset:
                right.append(row[index])
            else:
                left.append(row[index])
        for row in right:
            left.append(row)
        yield num, left

@step(name="round", args=[cast(int, "# of decimal places"), colset()])
def rounding(input, places, colset):
    for num, row in input:
        for index in colset.until(len(row)):
            value = convert(row[index], locale.atof)
            if type(value) == float:
                row[index] = round(value, places)
        yield num, row

####################################################################################################
#
# Column utils

class Columns:

    def __init__(self, list, rest):
        self.list, self.rest = list, rest
        self._set = set(self.list)

    @staticmethod
    def from_string(s):
        columns, rest = [], None
        for part in s.replace("c", "").split(","):
            if INTEGER.match(part):
                columns.append(int(part)-1)
            else:
                m = RANGE.match(part) or die("Bad column expression: " + part)
                if m.group(2) != "":
                    columns += [x for x in range(int(m.group(1)) - 1, int(m.group(2)))]
                elif rest is None or int(m.group(1)) - 1 < rest:
                    rest = int(m.group(1)) - 1
        return Columns(columns, rest)

    def until(self, max):
        """
        Iterate over the columns in the list, then if there is an open final range,
        iterate over the values in that until max.
        """
        for index in self.list:
            if index < max:
                yield index
        if self.rest is not None:
            for index in range(self.rest, max):
                yield index

    def __contains__(self, index):
        return index in self._set or (self.rest is not None and self.rest <= index)

def reformat(col, **options):

    """
    Format a column of values.If justify=true, left (for strings) or right (for numbers)
    justify in max length.  If comma=true, add comms to numbers.  Use 2 places of precision
    for formatting floats.  Type values based on the first ten items.
    """

    justify = "justify" in options
    comma = "comma" in options
    first, col = convert_column(col)

    if type(first) == str:
        if not justify:
            return col
        maxlen = max(len(s) for s in col)
        return [s.ljust(maxlen) for s in col]
    
    if type(first) == float:
        format = "{:,.2f}".format if comma else "{:.2f}".format
    else:
        format = "{:,}".format if comma else str

    col = map(format, col)
    if not justify:
        return col 
    maxlen = max(len(s) for s in col)
    return [s.rjust(maxlen) for s in col]

def convert_column(col, header=False):

    """
    Intuit a column's type and convert it.  Ignores the leading item if header=True.
    Returns the first converted item (or None), and column.
    """

    if len(col) == 0 or len(col) <= 1 and header:
        return None, map(str, col)
    start = 1 if header else 0
    sample = map(convert, col[start:start+20])

    if all(type(x) == int for x in sample):
        converter = lambda x: convert(x, locale.atoi)
    elif all(type(x) == float for x in sample):
        converter = lambda x: convert(x, locale.atof)
    else:
        converter = str

    result = col[:]
    for i in range(start, len(result)):
        result[i] = converter(col[i])
    return result[start], result

def convert(value, bias=None):
    """Intuit the type of a value and convert it.  Anything not a string is returned
    unchanged; otherwise we try ints, floats, and (eventually) dates."""
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

def stripcommas(value):
    return value.translate(None, NUMCOMMA) if NUMCOMMA in value else value

####################################################################################################
#
# Column utils

def warn(message):
    sys.stderr.write(message + "\n")

def die(message):
    warn(message)
    sys.exit(1)

def first(x): return x[0]
def second(x): return x[1]
def isnone(x): return x is None
def notnone(x): return x is not None
def consume(x): 
    for y in x: pass

####################################################################################################

locale.setlocale(locale.LC_ALL, "")

if locale.format("%.2f", 1.0) == "1,00":
    NUMCOMMA = "."
    NUMDOT = ","
else:
    NUMCOMMA = ","
    NUMDOT = "."

main(sys.argv[1:])
