
test(<<missing ema arg 1>>, <<ema>>, ps, <<>>, <<
Missing argument, expected EMA period
>>)

test(<<bad ema arg 1>>, <<ema x>>, ps, <<>>, <<
Expected EMA period but got x
>>)

test(<<missing ema arg 2>>, <<ema 1>>, ps, <<>>, <<
Missing argument, expected column expression
>>)

test(<<bad ema arg 2>>, <<ema 1 x>>, ps, <<>>, <<
Bad column expression: x
>>)

test(<<ema absent column>>, <<ema 1 99>>, ps, psout, <<>>)

test(<<ema 2 places>>, <<csv ema 2 2>>, <<
1.123,1.123,1.123
2.246,2.246,2.246
>>, <<
1.123,1.12,1.123
2.246,2.25,2.246
>>, <<>>)

