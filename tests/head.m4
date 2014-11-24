
test(<<missing head arg>>, <<head>>, ps, <<>>, <<
Missing argument, expected number of lines
>>)

test(<<bad head arg>>, <<head a>>, ps, <<>>, <<
Expected number of lines but got: a, error was: invalid literal for int() with base 10: '"'"'a'"'"'
>>)

test(<<head 0>>, <<head 0>>, ps, <<
>>, <<>>)

test(<<head 3>>, <<head 3>>, ps, <<
UID   PID  PPID   C STIME   TTY           TIME CMD
    0     1     0   0 22Oct14 ??        25:02.89 /sbin/launchd
    0    11     1   0 22Oct14 ??         0:12.72 /usr/libexec/UserEventAgent
>>, <<>>)

