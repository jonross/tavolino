
test("""missing keep arg""", """keep""", PS, """""", """
Missing argument, expected column expression
""")

test("""bad keep arg""", """keep x""", PS, """""", """
Invalid column: x
""")

test("""keep all""", """keep 1-""", PS, PSOUT, """""")

test("""keep flip""", """keep 2,1""", PS, """
PID	UID
1	0
11	0
12	0
14	0
15	0
16	0
17	0
18	0
19	0
""", """""")

test("""keep repeat""", """keep 2,2""", PS, """
PID	PID
1	1
11	11
12	12
14	14
15	15
16	16
17	17
18	18
19	19
""", """""")

test("""keep ranges""", """keep 1-3,5""", PS, """
UID	PID	PPID	STIME
0	1	0	22Oct14
0	11	1	22Oct14
0	12	1	22Oct14
0	14	1	22Oct14
0	15	1	22Oct14
0	16	1	22Oct14
0	17	1	22Oct14
0	18	1	22Oct14
0	19	1	22Oct14
""", """""")

test("""keep open range""", """keep 1,6-""", PS, """
UID	TTY	TIME	CMD
0	??	25:02.89	/sbin/launchd
0	??	0:12.72	/usr/libexec/UserEventAgent
0	??	0:26.80	/usr/libexec/kextd
0	??	6:27.11	/usr/sbin/notifyd
0	??	1:36.96	/usr/sbin/securityd
0	??	0:09.88	/usr/sbin/diskarbitrationd
0	??	11:31.90	/usr/libexec/configd
0	??	3:01.72	/System/Library/CoreServices/powerd.bundle/powerd
0	??	0:27.40	/usr/sbin/syslogd
""", """""")

