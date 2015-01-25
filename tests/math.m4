
test(<<missing round arg 1>>, <<round>>, ps, <<>>, <<
Missing argument, expected # of decimal places
>>)

test(<<bad round arg 1>>, <<round x>>, ps, <<>>, <<
Expected # of decimal places but got: x, error was: invalid literal for int() with base 10: '"'"'x'"'"'
>>)

test(<<missing round arg 2>>, <<round 1>>, ps, <<>>, <<
Missing argument, expected column expression
>>)

test(<<bad round arg 2>>, <<round 1 x>>, ps, <<>>, <<
Bad column expression: x
>>)

test(<<round absent column>>, <<round 1 99>>, ps, psout, <<>>)

test(<<round 2 places>>, <<round 2 2 csv>>, <<
1.123,1.123,1.123
2.246,2.246,2.246
>>, <<
1.123,1.12,1.123
2.246,2.25,2.246
>>, <<>>)

test(<<round 1 place>>, <<round 1 2 csv>>, <<
1.123,1.123,1.123
2.246,2.246,2.246
>>, <<
1.123,1.1,1.123
2.246,2.2,2.246
>>, <<>>)

test(<<round -1 places>>, <<round -1 2 csv>>, <<
1.123,12.2,1.123
2.246,16.2,2.246
>>, <<
1.123,10.0,1.123
2.246,20.0,2.246
>>, <<>>)

test(<<round all>>, <<round 0 1- csv>>, <<
1.123,12.2,1.123
2.246,16.2,2.246
>>, <<
1.0,12.0,1.0
2.0,16.0,2.0
>>, <<>>)

test(<<round non-numbers>>, <<round 1 2 csv>>, <<
1.123,foo,1.123
2.246,foo,2.246
>>, <<
1.123,foo,1.123
2.246,foo,2.246
>>, <<>>)

