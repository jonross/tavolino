#!/usr/bin/python2.7
#
# TODO: stop using Columns.list, not accurate

from collections import Counter, deque, namedtuple
from itertools import islice
import locale
from os import path
import re
import sys

INTEGER = re.compile("^\d+$")
RANGE = re.compile("^(\d+)-(\d*)$")
NSAMPLES = 20
STEPS = {}

Step = namedtuple("Step", "fn name argspecs groups")
GroupBy = namedtuple("Groups", "column aggregates")
Aggregate = namedtuple("Aggregate", "name fn colset")

NCOLUMNS = None

####################################################################################################

class State:

    """Operational settings that change as we parse each step."""

    def __init__(self, other=None):
        self.input = other.input if other else None
        self.header = other.header if other else False
        self.someinput = other.someinput if other else False
        self.ifs = other.ifs if other else None
        self.ofs = other.ofs if other else "\t"
        self.groupby = other.groupby if other else None

    def with_input(self, it):
        """Change the input iterator"""
        return changing(State(self), "input", it)

    def with_header(self, flag):
        """Indicate whether there is a header row"""
        return changing(State(self), "header", flag)

    def with_someinput(self, flag):
        """Indicate whether we are limiting the input"""
        return changing(State(self), "someinput", flag)

    def with_ifs(self, fs): 
        """Change input field separator"""
        return changing(State(self), "ifs", fs)

    def with_ofs(self, fs): 
        """Change output field separator"""
        return changing(State(self), "ofs", fs)

    def with_groupby(self, g):
        """Set or unset the current aggregate functions"""
        return changing(State(self), "groupby", g)

####################################################################################################

def main(args):

    # Set aside filenames at start of args

    args = deque(args)
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

    state = State()
    state = state.with_someinput("sip" in args)
    state = state.with_header("hdr" in args or "header" in args)
    ifs = None
    ofs = "\t"

    # Innermost input reader; handles stdin vs file list and applies line limit.

    def readinput(some):
        lineno = 0
        for f in (files or [sys.stdin]):
            for line in (f if type(f) == file else open(f)):
                lineno += 1
                yield line.rstrip()
                if some and lineno == 1000:
                    return

    # Second-level input reader; splits to columns, guesses delimiters, and
    # tags with line numbers.

    def readrows(ifs, some):
        input = readinput(some)
        head = list(islice(input, 0, NSAMPLES))
        if ifs is None:
            ifs = guess_ifs(head)
        if ifs == " ":
            ifs = None
        stripper = str.lstrip if ifs == " " else identity
        if NCOLUMNS is not None:
            splitter = lambda s: stripper(s).split(ifs, NCOLUMNS - 1)
        else:
            splitter = lambda s: stripper(s).split(ifs)
        yield []
        lineno = 1
        for line in head:
            yield lineno, splitter(line)
            lineno += 1
        for line in input:
            yield lineno, splitter(line)
            lineno += 1

    while len(args) > 0:

        word = args.popleft()
        words = expandalias(word)
        if words is not None:
            args.extendleft(reversed(words))
            continue

        # Handle special names for changing field separator.
        # TODO: redo as steps

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

        # Find step by name.  Before parsing args, make sure grouping steps have a group.

        step = STEPS.get(word) or die("Unknown step name: " + word)

        if state.groupby and not step.groups:
            state = state.with_groupby(None)
        elif not state.groupby and step.groups:
            args.extendleft(reversed(["groupby", "0"]))
            continue

        # Parse args, and run the step function.  This may:
        #  - return the input unchanged, but have side effects
        #  - wrap the input and return another iterator
        #  - return more args to process

        stepargs = parse(args, step.argspecs)
        if not state.input:
            state = state.with_input(readrows(ifs, state.someinput))
        result = step.fn(state, *stepargs)
        if type(result) == list:
            args.extendleft(reversed(result))
        else:
            state = state.with_input(result)

    # With no args, normalize whitespace

    if state.input is None:
        state = state.with_input(readrows(ifs, state.someinput))
        state = state.with_input(split(state))
        ofs = "\t"

    meta = next(state.input)
    for num, row in state.input:
        print ofs.join(map(str, row))

def guess_ifs(lines):
    """Guess the correct input field separator given a sample of lines.

    If the same nonzero number of tabs is present on each, use tab.
    Otherwise use the one of (whitespace, comma, pipe) that appears
    most frequently.
    """
    if len(lines) == 0:
        return " "
    def occurrences(line, sep): 
        return (line.count(" ") + line.count("\t")) if sep == " " else line.count(sep)
    ntabs = [occurrences(line, "\t") for line in lines]
    if ntabs[0] > 0 and all(map(lambda n: n == ntabs[0], ntabs)):
        return "\t"
    counts = [[(occurrences(line, sep), sep) for sep in " ,|"] for line in lines]
    bests = [second(max(c, key=first)) for c in counts]
    best = first(first(Counter(bests).most_common(1)))
    # print >>sys.stderr, "The best separator is", best
    return best

####################################################################################################

ALIASES = [ (re.compile(alias),expansion) for alias, expansion in [
    ("^avg$", ["average"]),
    ("^csv$", ["fs", ","]),
    ("^(hdr|header)$", []), # handled before arg parsing
    ("^ht$", ["headtail"]),
    ("^neat$", ["neaten"]),
    ("^max$", ["maximum"]),
    ("^min$", ["minimum"]),
    ("^nice$", ["neat", "1-", "ofs", "  "]),
    ("^per$", ["percent"]),
    ("^psv$", ["fs", "|"]),
    ("^s[/-_=,]", lambda word: expandsub(word)),
    ("^sip$", []), # handled before arg parsing
    ("^ssv$", ["fs", " "]),
    ("^tsv$", ["fs", "\t"]),
    ]
]

def expandalias(word):
    """Return alias expansion for a word, or None if none."""
    for regexp, expansion in ALIASES:
        if regexp.match(word):
            return expansion if type(expansion) == list else expansion(word)
    return None

def expandsub(word):
    """Handle alias expansion of s/pattern/replacement/flags;
    turn it into ["sub", "pattern", "replacement", "flags"]
    """
    sep = word[1]
    subpat = "^s%s([^%s]*)%s([^%s]*)%s([gi0-9]*)$" % tuple([sep] * 5)
    m = re.match(subpat, word)
    if not m:
        die("Expected substitution but got " + word)
    return ["sub", m.group(1), m.group(2), m.group(3) or ""]

####################################################################################################

ArgSpec = namedtuple("ArgSpec", "function docstring optional")

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

def step(name, args, groups=False):
    def wrap(f):
        step = Step(f, name, args, groups)
        STEPS[name] = step
        return f
    return wrap

@step(name="strip", args=[cast(str, "characters to remove")])
def strip(state, chars):
    yield next(state.input)
    for num, row in state.input:
        yield num, map(lambda cell: cell.translate(None, chars))

@step(name="head", args=[cast(int, "number of lines")])
def head(state, count):
    return islice(state.input, 0, count + 1)

@step(name="tail", args=[cast(int, "number of lines")])
def tail(state, count):
    yield next(state.input)
    for x in deque(state.input, count):
        yield x

@step(name="headtail", args=[])
def headtail(state):
    yield next(state.input)
    count = 0
    queue = deque()
    for num, row in state.input:
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
def keep(state, colset):
    yield next(state.input)
    for num, row in state.input:
        newrow = []
        for index in colset.until(len(row)):
            newrow.append(row[index])
        yield num, newrow

@step(name="drop", args=[colset()])
def drop(state, colset):
    yield next(state.input)
    for num, row in state.input:
        newrow = []
        for index in range(0, len(row)):
            if index not in colset:
                newrow.append(row[index])
        if len(newrow) > 0:
            yield num, newrow

@step(name="to", args=[])
def split(state):
    yield next(state.input)
    for num, row in state.input:
        yield num, row

@step(name="neaten", args=[colset()])
def neaten(state, colset):
    yield next(state.input)
    result = []
    for num, row in state.input:
        result.append((num, row))
    rows = map(second, result)
    maxlen = max(map(len, rows))
    for index in colset.until(maxlen):
        column = [row[index] for row in rows]
        newcolumn = reformat(column, header=state.header, justify=True, comma=True)
        for row, cell in zip(rows, newcolumn):
            row[index] = cell
    for num, row in result:
        yield num, row

@step(name="ord", args=[])
def inorder(state):
    meta = next(state.input)
    meta.insert(0, Metadata(int, int, state.header))
    yield meta
    for num, row in state.input:
        row.insert(0, num)
        yield num, row

@step(name="percent", args=[colset()])
def add_percent(state, colset):
    yield next(state.input)
    result = []
    for num, row in state.input:
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
def add_cum(state, colset):
    yield next(state.input)
    result = []
    for num, row in state.input:
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
def substitute(state, pat, rep, flags, colset):
    yield next(state.input)
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
    for num, row in state.input:
        if num > 0:
            for index in colset.until(len(row)):
                row[index] = pat.sub(rep, row[index], count)
        yield num, row

@step(name="left", args=[colset()])
def pull_left(state, colset):
    yield next(state.input)
    # TODO optimize for fixed length
    for num, row in state.input:
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
def pull_right(state, colset):
    yield next(state.input)
    # TODO optimize for fixed length
    for num, row in state.input:
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
def rounding(state, places, colset):
    yield next(state.input)
    for num, row in state.input:
        for index in colset.until(len(row)):
            value = convert(row[index], locale.atof)
            if type(value) == float:
                row[index] = round(value, places)
        yield num, row

####################################################################################################

@step(name="groupby", args=[cast(int, "column number")])
def groupby(state, column):
    """
    Start a new data group; subsequent grouping steps append their information to this, 
    until a non-grouping step is encountered.  Note: this step does not have groups=True,
    because if there is an active group, we should close it and start a new one.
    """
    global GROUPBY
    GROUPBY = GroupBy(column - 1, [])
    def dogroup(groupby, input):
        meta = next(input)
        yield meta
        groups = defaultdict(lambda: [])
        if groupby.column == 0:
            groups[0] = map(second, input)
        else:
            for _, row in input:
                groups[row[groupby.column]].append(row)
        for key in groups:
            used = set(groupby.column)
            columns = [m.convert(c) for m, c in zip(meta, transpose(groups[key]))]
            results = [None] * meta.size
            for agg in group.aggregates:
                for index in agg.colset:
                    used.add(index)
                    results[index] = agg.fn(columns[index])
            groups[key] = [results[index] for index in sorted(used)]
        for num, group in enumerate(groups.iteritems()):
            yield num, group

    return dogroup(GROUPBY, state.input)

@step(name="sum", args=[colset()], groups=True)
def dosum(state, colset):
    """Add a SUM aggregate to the established GroupBy"""
    GROUPBY.aggregates.append(Aggregate("SUM", sum, colset))

@step(name="average", args=[colset()], groups=True)
def doavg(state, colset):
    """Add an AVERAGE aggregate to the established GroupBy"""
    GROUPBY.aggregates.append(Aggregate("AVERAGE", avg, colset))

@step(name="minimum", args=[colset()], groups=True)
def doavg(state, colset):
    """Add a MIN aggregate to the established GroupBy"""
    GROUPBY.aggregates.append(Aggregate("MINIMUM", min, colset))

@step(name="maximum", args=[colset()], groups=True)
def doavg(state, colset):
    """Add a MAX aggregate to the established GroupBy"""
    GROUPBY.aggregates.append(Aggregate("MAXIMUM", max, colset))

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
        """Iterate over the columns in the list, then if there is an open final range,
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

class Metadata:

    """Information about a column's type"""

    def __init__(self, kind, converter, header, absent=False):
        # Not enough data available to determine
        self.absent = absent
        # str, int, float or date
        self.kind = kind
        # How to convert values
        self._converter = converter
        # Dataset has a header
        self.header = header

    @staticmethod
    def from_data(col, header):
        """Sample values from a column, ignoring a possible header, and return
        a new Metadata instance.
        """
        if len(col) == 0 or len(col) <= 1 and self.header:
            return Metadata(str, str, header, true)
        start = 1 if header else 0
        sample = map(convert, col[start:start+NSAMPLES])
        if all(type(x) == int for x in sample):
            return Metadata(int, lambda x: convert(x, locale.atoi), header)
        elif all(type(x) == float for x in sample):
            return Metadata(float, lambda x: convert(x, locale.atof), header)
        else:
            return Metadata(str, str, header)

    def convert(self, col):
        """Convert a column of values, returning the first converted value
        separately (this is None if there are no discernible values.)
        """
        if self.absent:
            return None, map(str, col)
        start = 1 if self.header else 0
        result = col[:]
        for i in range(start, len(result)):
            result[i] = self._converter(col[i])
        return result[start], result

def reformat(col, header=False, justify=False, comma=False):

    """Format a column of values.
    
    If justify=true, left (for strings) or right (for numbers)
    justify in max length.  If comma=true, add comms to numbers.  Use 2 places of precision
    for formatting floats.  Type values based on the first ten items.
    """

    first, col = Metadata.from_data(col, header).convert(col)

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

def convert(value, bias=None):
    """Intuit the type of a value and convert it.  
    
    Anything not a string is returned unchanged; otherwise we 
    try ints, floats, and (eventually) dates.
    """
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

def warn(message):
    sys.stderr.write(message + "\n")

def die(message):
    warn(message)
    sys.exit(1)

def identity(x): return x
def first(x): return x[0]
def second(x): return x[1]
def isnone(x): return x is None
def notnone(x): return x is not None
def changing(obj, attr, val): return setattr(obj, attr, val) or obj

####################################################################################################

locale.setlocale(locale.LC_ALL, "")

if locale.format("%.2f", 1.0) == "1,00":
    NUMCOMMA = "."
    NUMDOT = ","
else:
    NUMCOMMA = ","
    NUMDOT = "."

main(sys.argv[1:])
