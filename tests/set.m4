
test(<<missing set arg 1>>, <<set>>, ps, <<>>, <<
Missing argument, expected cN=EXPRESSION
>>)

test(<<bad set arg 1>>, <<set x>>, ps, <<>>, <<
Expected cN=EXPRESSION but got x
>>)

test(<<set simple 1>>, <<csv set 'c2=int(c1)+5'>>, <<
1,x
2,x
3,x
>>, <<
1,6
2,7
3,8
>>, <<>>)

test(<<set missing index>>, <<csv set 'c2=int(c1)+5'>>, <<
1
2
3
>>, <<
1
2
3
>>, <<>>)

