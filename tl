#!/usr/bin/env python3

from collections import namedtuple
from datetime import date, datetime, time
from itertools import chain, tee
from pathlib import Path
import locale
import operator as op
import re
import sys

sys.path.append(str(Path(__file__).parent / "src"))

from tl.args import parse_argv
from tl.table import Table, Column
from tl.types import guess_separators, guess_type, make_format

# Match any run of whitespace
WHITESPACE = re.compile(r"\s+")

def main(argv):

    steps, options = parse_argv(argv)
    lines = list(map(str.strip, sys.stdin))
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

    rows = map(splitter, lines)
    widest = max(map(len, rows))
    widen = lambda row: row if len(row) == widest else row + [None] * (widest - len(row))
    rows = map(widen, rows)

    # Transpose to columns & run steps, then back to rows for output.

    table = Table([list(c) for c in zip(*rows)])
    for step in steps:
        step(table)

    if table.columns and not table.suppress:
        for row in zip(*(column.data for column in table.columns)):
            print(join_on.join(map(lambda x: "" if x is None else str(x), row)))

####################################################################################################

####################################################################################################

####################################################################################################

main(sys.argv[1:])

