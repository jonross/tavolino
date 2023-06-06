import itertools as it
import sys

def die(message):
    sys.exit(message + "\n")

def notnone(x):
    return x is not None

def coalesce(seq):
    return next(filter(notnone, iter(seq)), None)

def pairwise(seq):
    a, b = it.tee(seq)
    next(b, None)
    return zip(a, b)

def with_prev(seq, first_prev=None):
    return pairwise(it.chain([first_prev], seq))

def remap(f, list, value=None):
    v = [list[0]] if value is None else [value]
    def f2(x):
        v[0] = f(v[0], x)
        return v[0]
    return map(f2, list)


