
test("""missing ema arg 1""", """ema""", PS, """""", """
Missing argument, expected EMA period
""")

test("""bad ema arg 1""", """ema x""", PS, """""", """
Expected EMA period but got x
""")

test("""missing ema arg 2""", """ema 1""", PS, """""", """
Missing argument, expected column expression
""")

test("""bad ema arg 2""", """ema 1 x""", PS, """""", """
Invalid column: x
""")

test("""ema absent column""", """ema 1 99""", PS, PSOUT, """""")

test("""ema""", """csv ema 4 1""", """
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

