
test("""missing per arg""", """per""", PS, """""", """
Missing argument, expected column expression
""")

test("""bad per arg""", """per x""", PS, """""", """
Invalid column: x
""")

test("""per""", """per 1,4""", """
1 a b 6
3 c d 3
6 e f 1
""", """
1	10.0	a	b	6	60.0
3	30.0	c	d	3	30.0
6	60.0	e	f	1	10.0
""", """""")

test("""per with null""", """per 1,4""", """
1 a b 3
3 c d 2
6 e f
""", """
1	10.0	a	b	3	60.0
3	30.0	c	d	2	40.0
6	60.0	e	f		0
""", """""")

