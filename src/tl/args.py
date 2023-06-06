import collections as co
import re

from tl.steps import *
from tl.utils import *

# Match a string containing only an integer, with no whitespace
INTEGER = re.compile("^\d+$")
# Match e.g. "1-3" or "8-"
RANGE = re.compile("^(\d+)-(\d*)$")
# Match e.g. "1-3,5,8-"
RANGES = re.compile("^[0-9-]+(,[0-9-]+)*$")
# Command-line synonyms for common field separators
SEPARATOR_NAMES = { "csv" : ",", "psv" : "|", "ssv" : " ", "tsv" : "\t" }

# Holds information from the command line other than step functions
Options = co.namedtuple("Options", "split_on join_on")

def silent(f):
    def wrapped(*args):
        try:
            return f(*args)
        except:
            return None
    return wrapped

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

# A dict describing how to parse options for step names.
# Keys are step names, and the values are an array of tuples, one per arg, with each tuple
# containing a description of the arg, and a function to parse it (returning None on failure.)

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
        step_fn = eval(f"do_{arg}")
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

