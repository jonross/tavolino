
test("""missing round arg 1""", """round""", PS, """""", """
Missing argument, expected # of places
""")

test("""bad round arg 1""", """round x""", PS, """""", """
Expected # of places but got x
""")

test("""missing round arg 2""", """round 1""", PS, """""", """
Missing argument, expected column expression
""")

test("""bad round arg 2""", """round 1 x""", PS, """""", """
Invalid column: x
""")

test("""round absent column""", """round 1 99""", PS, PSOUT, """""")

test("""round 2 places""", """csv round 2 2""", """
1.123,1.123,1.123
2.246,2.246,2.246
""", """
1.123,1.12,1.123
2.246,2.25,2.246
""", """""")

test("""round 1 place""", """csv round 1 2""", """
1.123,1.123,1.123
2.246,2.246,2.246
""", """
1.123,1.1,1.123
2.246,2.2,2.246
""", """""")

test("""round -1 places""", """csv round -1 2""", """
1.123,12.2,1.123
2.246,16.2,2.246
""", """
1.123,10.0,1.123
2.246,20.0,2.246
""", """""")

test("""round all""", """csv round 0 1-""", """
1.123,12.2,1.123
2.246,16.2,2.246
""", """
1.0,12.0,1.0
2.0,16.0,2.0
""", """""")

