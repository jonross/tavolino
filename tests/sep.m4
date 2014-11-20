
test(<<simple space detection>>, <<to psv>>, <<
  a  b
>>, <<
a|b
>>, <<>>)

test(<<same number of tabs>>, <<to psv>>, <<
a	b	c
d	e	f
g		h
>>, <<
a|b|c
d|e|f
g||h
>>, <<>>)

test(<<different number of tabs>>, <<to psv>>, <<
a	b	c
d	e	f
g	h
>>, <<
a|b|c
d|e|f
g|h
>>, <<>>)

test(<<spaces win>>, <<to psv>>, <<
a, b, c
d, e, f
g h
>>, <<
a,|b,|c
d,|e,|f
g|h
>>, <<>>)

test(<<commas win>>, <<to psv>>, <<
a, b,, c
d, e,, f
g h,
>>, <<
a| b|| c
d| e|| f
g h|
>>, <<>>)

test(<<pipes win>>, <<to csv>>, <<
a| b |c
d|e|f
g|h
>>, <<
a, b ,c
d,e,f
g,h
>>, <<>>)

