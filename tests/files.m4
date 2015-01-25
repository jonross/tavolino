
(echo a; echo b) >t.1
(echo c; echo d) >t.2

test(<<missing file>>, <<not.found>>, <<>>, <<>>, <<
File not.found not found
>>)

test(<<missing files>>, <<not.found1 not.found2>>, <<>>, <<>>, <<
File not.found1 not found
File not.found2 not found
>>)

test(<<read files>>, <<t.1 t.2>>, <<
notread
>>, <<
a
b
c
d
>>, <<>>)

