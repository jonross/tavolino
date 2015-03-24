
test(<<missing add arg 1>>, <<add>>, ps, <<>>, <<
Missing argument, expected EXPRESSION
>>)

test(<<add simple 1>>, <<csv add 'int(c1)+5'>>, <<
1
2
3
>>, <<
1,6
2,7
3,8
>>, <<>>)

test(<<touch missing index>>, <<csv add 'int(c2)+5'>>, <<
1
2
3
>>, <<
1
2
3
>>, <<>>)

