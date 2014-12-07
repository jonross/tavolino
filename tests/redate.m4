
test(<<missing redate format>>, <<redate>>, ps, <<>>, <<
Missing argument, expected date format
>>)

test(<<missing redate column>>, <<redate x>>, ps, <<>>, <<
Missing argument, expected column expression
>>)

test(<<bad redate column>>, <<redate x a>>, ps, <<>>, <<
Bad column expression: a
>>)

test(<<redate>>, <<ssv redate %Y-%m-%d 1,3>>, <<
36000 36600 1/2/03
36000 36000 12/25/99
>>, <<
1970-01-01 36600 2003-01-02
1970-01-01 36000 1999-12-25
>>, <<>>)

