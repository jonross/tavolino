
test(<<missing per arg>>, <<per>>, ps, <<>>, <<
Missing argument, expected column expression
>>)

test(<<bad per arg>>, <<per x>>, ps, <<>>, <<
Bad column expression: x
>>)

test(<<per>>, <<per 1,4>>, <<
1 a b 6
3 c d 3
6 e f 1
>>, <<
1	10.0	a	b	6	60.0
3	30.0	c	d	3	30.0
6	60.0	e	f	1	10.0
>>, <<>>)

