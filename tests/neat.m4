
test(<<missing neat arg>>, <<neat>>, ps, <<>>, <<
Missing argument, expected column expression
>>)

test(<<bad neat arg>>, <<neat x>>, ps, <<>>, <<
Bad column expression: x
>>)

test(<<neat 1>>, <<neat 1 csv>>, <<
3 12
18 7
140 110
>>, <<
  3,12
 18,7
140,110
>>, <<>>)

test(<<neat 2>>, <<neat 2 csv>>, <<
3 12
18 7
140 110
>>, <<
3, 12
18,  7
140,110
>>, <<>>)

test(<<neat all>>, <<neat 1- ss>>, <<
3 4.1 foo
150 88.9041 foobar
>>, <<
  3  4.10 foo   
150 88.90 foobar
>>, <<>>)

