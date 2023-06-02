def test_dup_missing_arg(run):
    run("dup", stderr="Missing argument, expected column expression\n")

def test_dup_invalid_column(run):
    run("dup x", stderr="Invalid column: x\n")


def test_dup_columns(run):
    run("dup 1,4 to csv", stdin="""
        1 a b 6
        3 c d 3
        6 e f 1
    """, stdout="""
        1,1,a,b,6,6
        3,3,c,d,3,3
        6,6,e,f,1,1
    """)
