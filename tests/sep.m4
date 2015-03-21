
test(<<excess spaces>>, <<to psv>>, <<
  a  b  
>>, <<
a|b
>>, <<>>)

test(<<commas win>>, <<to psv>>, <<
a, b, c,d
d,  e,f,g
>>, <<
a| b| c|d
d|  e|f|g
>>, <<>>)

test(<<pipes win>>, <<to tsv>>, <<
a|,b|,c|d
d|,,e|f|g
>>, <<
a	,b	,c	d
d	,,e	f	g
>>, <<>>)

test(<<blank tab>>, <<to psv>>, <<
a	b	c
d	e	f
g		h
>>, <<
a|b|c
d|e|f
g||h
>>, <<>>)

test(<<tabs win>>, <<to psv>>, <<
a	b	c
d	e	f
g	h	i
>>, <<
a|b|c
d|e|f
g|h|i
>>, <<>>)

test(<<explicit tabs>>, <<tsv to psv>>, <<
a	b	c
d	e	f
g		h
>>, <<
a|b|c
d|e|f
g||h
>>, <<>>)

test(<<explicit psv>>, <<psv to csv>>, <<
a | b | c
d | e | f
g | h
>>, <<
a , b , c
d , e , f
g , h,
>>, <<>>)

test(<<explicit csv>>, <<csv to psv>>, <<
a , b , c
d , e , f
g , h
>>, <<
a | b | c
d | e | f
g | h|
>>, <<>>)

test(<<explicit ssv>>, <<ssv to psv>>, <<
a , b , c
d , e , f
g , h
>>, <<
a|,|b|,|c
d|,|e|,|f
g|,|h||
>>, <<>>)

