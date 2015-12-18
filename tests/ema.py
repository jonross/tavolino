
test("""missing ema arg 1""", """ema""", PS, """""", """
Missing argument, expected column expression
""")

test("""bad ema arg 1""", """ema x""", PS, """""", """
Invalid column: x
""")

test("""missing ema arg 2""", """ema 1""", PS, """""", """
Missing argument, expected EMA period
""")

test("""bad ema arg 2""", """ema 1 x""", PS, """""", """
Expected EMA period but got x
""")

test("""ema absent column""", """ema 99 1""", PS, PSOUT, """""")

test("""ema""", """csv ema 1 4""", """
0
8
8
8
""", """
0,0.0
8,2.0
8,3.5
8,4.625
""", """""")

test("""ema with null row""", """csv ema 1 4""", """
0
8

8
""", """
0,0.0
8,2.0
,2.0
8,3.5
""", """""")

