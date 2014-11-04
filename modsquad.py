
import re, sys

NUMBER = re.compile("^\d+$")
RANGE = re.compile("^(\d+)-(\d+)$")

def parse_columns(expr):
    columns = []
    for nums in expr.replace("c", "").split(","):
        if NUMBER.match(nums):
            columns.append(int(nums) - 1)
        else:
            m = RANGE.match(nums)
            if m:
                columns += [x for x in range(int(m.group(1)) - 1, int(m.group(2)))]
            else:
                die("Bad column expression: " + expr)
    return columns

def tsv_input():
    first = sys.stdin.readline().strip("\n")
    if "\t" in first:
        yield first.split("\t")
        for line in sys.stdin:
            yield line.strip("\n").split("\t")
    else:
        ncommas = nspaces = 0
        for char in first:
            if char == ",":
                ncommas += 1
            elif char == " ":
                nspaces += 1
        if ncommas > nspaces:
            splitter = lambda s: s.split(",")
        else:
            splitter = lambda s: s.split()
        yield splitter(first)
        for line in sys.stdin:
            yield splitter(line.strip("\n"))

def parse_number(s):
    """
    Parses a number from a string, or returns None if unable.  Removes
    commas first (sorry, Europe.)  Return type is float or int depending
    on the presence of '.' in the string.
    """
    if "," in s:
        s = s.replace(",", "")
    try:
        return float(s) if "." in s else int(s)
    except ValueError:
        return None

def as_integer(s):
    try:
        return int(s)
    except ValueError:
        return None

def die(message):
    sys.stderr.write(message + "\n")
    sys.exit(1)


