import locale
import re

# Match any run of whitespace
WHITESPACE = re.compile(r"\s+")
# Match a date in YYYY-MM-DD format
DATE_YYYYMMDD = re.compile("^(\d\d\d\d)-(\d\d)-(\d\d)$")

# Are numbers like "1,000.00" or "1.000,00"
locale.setlocale(locale.LC_ALL, "")
if locale.format("%.2f", 1.0) == "1,00":
    NUMCOMMA, NUMDOT = ".", ","
else:
    NUMCOMMA, NUMDOT = ",", "."

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

