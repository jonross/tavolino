
(echo a; echo b) >t.1
(echo c; echo d) >t.2

test(<<missing file>>, <<not.found>>, <<>>, <<>>, <<
File not.found not found
>>)

test(<<read files>>, <<t.1 t.2>>, <<
notread
>>, <<
a
b
c
d
>>, <<>>)

test(<<limit in one file>>, <<t.* just 1>>, <<>>, <<
a
>>, <<>>)

test(<<limit in second file>>, <<t.* just 3>>, <<>>, <<
a
b
c
>>, <<>>)

test(<<no-op limit>>, <<t.* just 10>>, <<>>, <<
a
b
c
d
>>, <<>>)
