

test(<<missing left arg>>, <<left>>, ps, <<>>, <<
Missing argument, expected column expression
>>)

test(<<missing right arg>>, <<right>>, ps, <<>>, <<
Missing argument, expected column expression
>>)

test(<<bad left arg>>, <<left x>>, ps, <<>>, <<
Bad column expression: x
>>)

test(<<bad right arg>>, <<left x>>, ps, <<>>, <<
Bad column expression: x
>>)

test(<<no-op left>>, <<left 99>>, ps, psout, <<>>)

test(<<no-op right>>, <<right 99>>, ps, psout, <<>>)

test(<<left 2,4>>, <<left 2,4>>, ps, <<
PID	C	UID	PPID	STIME	TTY	TIME	CMD
1	0	0	0	22Oct14	??	25:02.89	/sbin/launchd
11	0	0	1	22Oct14	??	0:12.72	/usr/libexec/UserEventAgent
12	0	0	1	22Oct14	??	0:26.80	/usr/libexec/kextd
14	0	0	1	22Oct14	??	6:27.11	/usr/sbin/notifyd
15	0	0	1	22Oct14	??	1:36.96	/usr/sbin/securityd
16	0	0	1	22Oct14	??	0:09.88	/usr/sbin/diskarbitrationd
17	0	0	1	22Oct14	??	11:31.90	/usr/libexec/configd
18	0	0	1	22Oct14	??	3:01.72	/System/Library/CoreServices/powerd.bundle/powerd
19	0	0	1	22Oct14	??	0:27.40	/usr/sbin/syslogd
>>, <<>>)

test(<<left all>>, <<left 1->>, ps, <<
UID	PID	PPID	C	STIME	TTY	TIME	CMD
0	1	0	0	22Oct14	??	25:02.89	/sbin/launchd
0	11	1	0	22Oct14	??	0:12.72	/usr/libexec/UserEventAgent
0	12	1	0	22Oct14	??	0:26.80	/usr/libexec/kextd
0	14	1	0	22Oct14	??	6:27.11	/usr/sbin/notifyd
0	15	1	0	22Oct14	??	1:36.96	/usr/sbin/securityd
0	16	1	0	22Oct14	??	0:09.88	/usr/sbin/diskarbitrationd
0	17	1	0	22Oct14	??	11:31.90	/usr/libexec/configd
0	18	1	0	22Oct14	??	3:01.72	/System/Library/CoreServices/powerd.bundle/powerd
0	19	1	0	22Oct14	??	0:27.40	/usr/sbin/syslogd
>>, <<>>)

test(<<right 2,4>>, <<right 2,4>>, ps, <<
UID	PPID	STIME	TTY	TIME	CMD	PID	C
0	0	22Oct14	??	25:02.89	/sbin/launchd	1	0
0	1	22Oct14	??	0:12.72	/usr/libexec/UserEventAgent	11	0
0	1	22Oct14	??	0:26.80	/usr/libexec/kextd	12	0
0	1	22Oct14	??	6:27.11	/usr/sbin/notifyd	14	0
0	1	22Oct14	??	1:36.96	/usr/sbin/securityd	15	0
0	1	22Oct14	??	0:09.88	/usr/sbin/diskarbitrationd	16	0
0	1	22Oct14	??	11:31.90	/usr/libexec/configd	17	0
0	1	22Oct14	??	3:01.72	/System/Library/CoreServices/powerd.bundle/powerd	18	0
0	1	22Oct14	??	0:27.40	/usr/sbin/syslogd	19	0
>>, <<>>)

test(<<right all>>, <<right 1->>, ps, <<
UID	PID	PPID	C	STIME	TTY	TIME	CMD
0	1	0	0	22Oct14	??	25:02.89	/sbin/launchd
0	11	1	0	22Oct14	??	0:12.72	/usr/libexec/UserEventAgent
0	12	1	0	22Oct14	??	0:26.80	/usr/libexec/kextd
0	14	1	0	22Oct14	??	6:27.11	/usr/sbin/notifyd
0	15	1	0	22Oct14	??	1:36.96	/usr/sbin/securityd
0	16	1	0	22Oct14	??	0:09.88	/usr/sbin/diskarbitrationd
0	17	1	0	22Oct14	??	11:31.90	/usr/libexec/configd
0	18	1	0	22Oct14	??	3:01.72	/System/Library/CoreServices/powerd.bundle/powerd
0	19	1	0	22Oct14	??	0:27.40	/usr/sbin/syslogd
>>, <<>>)

