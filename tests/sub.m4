

test(<<missing sub column>>, <<s/a/b/>>, ps, <<>>, <<
Missing argument, expected column expression
>>)

test(<<bad sub expr>>, <<s/a/b- 1>>, ps, <<>>, <<
Expected regexp / replacement but got s/a/b-
>>)

test(<<bad sub flag>>, <<s/a/b/h 1>>, ps, <<>>, <<
Bad regexp flag: h
>>)

test(<<bad sub column>>, <<s/a/b/ x>>, ps, <<>>, <<
Bad column expression: x
>>)

test(<<sub 1>>, <<csv s/a/b/ 1,3>>, <<
aaa,aaa,aaa,aaa
aab,aab,aab,aab
>>, <<
baa,aaa,baa,aaa
bab,aab,bab,aab
>>, <<>>)

test(<<sub 2>>, <<csv s/a/b/2 1,3>>, <<
aaa,aaa,aaa,aaa
aab,aab,aab,aab
>>, <<
bba,aaa,bba,aaa
bbb,aab,bbb,aab
>>, <<>>)

test(<<sub g>>, <<csv s/a/b/g 1,3>>, <<
aaa,aaa,aaa,aaa
aab,aab,aab,aab
>>, <<
bbb,aaa,bbb,aaa
bbb,aab,bbb,aab
>>, <<>>)


test(<<sub i>>, <<csv s/a/b/i 1,3>>, <<
AAA,AAA,AAA,AAA
AAB,AAB,AAB,AAB
>>, <<
bAA,AAA,bAA,AAA
bAB,AAB,bAB,AAB
>>, <<>>)


