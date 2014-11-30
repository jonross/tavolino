
test(<<missing tail arg>>, <<tail>>, ps, <<>>, <<
Missing argument, expected number of lines
>>)

test(<<bad tail arg>>, <<tail a>>, ps, <<>>, <<
Expected number of lines but got: a, error was: invalid literal for int() with base 10: '"'"'a'"'"'
>>)

test(<<tail 0>>, <<tail 0>>, ps, <<
>>, <<>>)

test(<<tail 3>>, <<tail 3>>, ps, <<
0	17	1	0	22Oct14	??	11:31.90	/usr/libexec/configd
0	18	1	0	22Oct14	??	3:01.72	/System/Library/CoreServices/powerd.bundle/powerd
0	19	1	0	22Oct14	??	0:27.40	/usr/sbin/syslogd
>>, <<>>)

