import pytest

def test_cum_missing_arg(run):
    run("cum", stderr="Missing argument, expected column expression\n")

def test_cum_invalid_column(run):
    run("cum x", stderr="Invalid column: x\n")

def test_cum_ints(run):
    run("cum 1,4", stdin="""
        1 a b 6
        3 c d 3
        6 e f 1
    """, stdout="""
        1	1	a	b	6	6
        3	4	c	d	3	9
        6	10	e	f	1	10
    """)

if False:

    test("""cum""", """cum 1,4""", """
    """, """
    """, """""")

    test("""cum""", """cum 1,4""", """
    1.0 a b 6.0
    3.0 c d 3.0
    6.0 e f 1.0
    """, """
    1.0	1.0	a	b	6.0	6.0
    3.0	4.0	c	d	3.0	9.0
    6.0	10.0	e	f	1.0	10.0
    """, """""")

