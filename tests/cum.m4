
test(<<missing cum arg>>, <<cum>>, ps, <<>>, <<
Missing argument, expected column expression
>>)

test(<<bad cum arg>>, <<cum x>>, ps, <<>>, <<
Bad column expression: x
>>)

test(<<cum>>, <<cum 1,4>>, <<
1 a b 6
3 c d 3
6 e f 1
>>, <<
1	1	a	b	6	6
3	4	c	d	3	9
6	10	e	f	1	10
>>, <<>>)

test(<<cum>>, <<cum 1,4>>, <<
1.0 a b 6.0
3.0 c d 3.0
6.0 e f 1.0
>>, <<
1.0	1.0	a	b	6.0	6.0
3.0	4.0	c	d	3.0	9.0
6.0	10.0	e	f	1.0	10.0
>>, <<>>)

