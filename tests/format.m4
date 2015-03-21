
test(<<neat empty>>, <<neat>>, <<>>, <<>> <<>>)

test(<<wiki empty>>, <<wiki>>, <<>>, <<>> <<>>)

test(<<neat basic>>, <<neat>>, <<
Jon 10 20.0
Jim 500 800.0
Jill 3 4.0
>>, <<
Jon    10   20.00
Jim   500  800.00
Jill    3    4.00
>>, <<>>)

test(<<wiki basic>>, <<wiki>>, <<
Jon 10 20.0
Jim 500 800.0
Jill 3 4.0
>>, <<
| Jon |  10 |  20.00 |
| Jim |  500 |  800.00 |
| Jill |  3 |  4.00 |
>>, <<>>)

