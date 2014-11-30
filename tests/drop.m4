

test(<<missing drop arg>>, <<drop>>, ps, <<>>, <<
Missing argument, expected column expression
>>)

test(<<bad drop arg>>, <<drop x>>, ps, <<>>, <<
Bad column expression: x
>>)

test(<<no-op drop>>, <<drop 99>>, ps, psout, <<>>)

test(<<drop 2,4>>, <<drop 2,4>>, ps, <<
UID	PPID	STIME	TTY	TIME	CMD
0	0	22Oct14	??	25:02.89	/sbin/launchd
0	1	22Oct14	??	0:12.72	/usr/libexec/UserEventAgent
0	1	22Oct14	??	0:26.80	/usr/libexec/kextd
0	1	22Oct14	??	6:27.11	/usr/sbin/notifyd
0	1	22Oct14	??	1:36.96	/usr/sbin/securityd
0	1	22Oct14	??	0:09.88	/usr/sbin/diskarbitrationd
0	1	22Oct14	??	11:31.90	/usr/libexec/configd
0	1	22Oct14	??	3:01.72	/System/Library/CoreServices/powerd.bundle/powerd
0	1	22Oct14	??	0:27.40	/usr/sbin/syslogd
>>, <<>>)

test(<<drop all but 1>>, <<drop 1,2-3,5->>, ps, <<
C
0
0
0
0
0
0
0
0
0
>>, <<>>)

test(<<drop all>>, <<drop 1->>, ps, <<
>>, <<>>)

