
test(<<missing dup arg>>, <<dup>>, ps, <<>>, <<
Missing argument, expected column expression
>>)

test(<<bad dup arg>>, <<dup x>>, ps, <<>>, <<
Bad column expression: x
>>)

test(<<dup>>, <<dup 1,4 to csv>>, <<
1 a b 6
3 c d 3
6 e f 1
>>, <<
1,1,a,b,6,6
3,3,c,d,3,3
6,6,e,f,1,1
>>, <<>>)

