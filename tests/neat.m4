
test(<<missing neat arg>>, <<neat>>, ps, <<>>, <<
Missing argument, expected column expression
>>)

test(<<bad neat arg>>, <<neat x>>, ps, <<>>, <<
Bad column expression: x
>>)

test(<<neat 1>>, <<neat 1 psv>>, <<
3 12
18 7
140 110
1,111 2,222
>>, <<
    3|12
   18|7
  140|110
1,111|2,222
>>, <<>>)

test(<<neat all>>, <<neat 1- ssv>>, <<
3 4.1 foo
150 8,888.8888 foobar
>>, <<
  3     4.10 foo   
150 8,888.89 foobar
>>, <<>>)

