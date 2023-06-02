
def test_empty_ord(run):
    run("ord")

def test_ord(run):
    run("ord", stdin="""
        a b c
        d e f
    """, stdout="""
        1	a	b	c
        2	d	e	f
    """)
