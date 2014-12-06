
test(<<missing maxcols arg>>, <<mc>>, <<>>, <<>>, <<
Missing argument, expected column limit
>>)

test(<<bad maxcols arg>>, <<mc a>>, <<>>, <<>>, <<
Expected column limit but got: a, error was: invalid literal for int() with base 10: '"'"'a'"'"'
>>)

test(<<maxcols 0>>, <<mc 0 to csv>>, <<
a b c
>>, <<
a b c
>>, <<>>)

test(<<maxcols 1>>, <<mc 1 to csv>>, <<
a b c
>>, <<
a b c
>>, <<>>)

test(<<maxcols 2>>, <<mc 2 to csv>>, <<
a b c
>>, <<
a,b c
>>, <<>>)

test(<<maxcols exact>>, <<mc 3 to csv>>, <<
a b c
>>, <<
a,b,c
>>, <<>>)

test(<<maxcols too big>>, <<mc 5 to csv>>, <<
a b c
>>, <<
a,b,c
>>, <<>>)

test(<<maxcols alias 1>>, <<maxcol 2 to csv>>, <<
a b c
>>, <<
a,b c
>>, <<>>)

test(<<maxcols alias 2>>, <<maxcols 2 to csv>>, <<
a b c
>>, <<
a,b c
>>, <<>>)

test(<<maxcols alias 3>>, <<maxcolumns 2 to csv>>, <<
a b c
>>, <<
a,b c
>>, <<>>)

