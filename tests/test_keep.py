def test_keep_missing_arg(run):
    run("keep", stderr="Missing argument, expected column expression\n")

def test_keep_invalid_column(run):
    run("keep x", stderr="Invalid column: x\n")

def test_keep_all_columns(run, long_ps, long_ps_tsv):
    run("keep 1-", stdin=long_ps, stdout=long_ps_tsv)

def test_keep_flip(run, short_ps):
    run("keep 2,1", stdin=short_ps, stdout="""
        PID	UID
        11	0
        12	0
        14	0
    """)

def test_keep_repeat(run, short_ps):
    run("keep 2,2", stdin=short_ps, stdout="""
        PID	PID
        11	11	
        12	12
        14	14
    """)

def test_keep_ranges(run, short_ps):
    run("keep 1-3,5", stdin=short_ps, stdout="""
        UID	PID	PPID	STIME
        0	11	1	22Oct14
        0	12	1	22Oct14
        0	14	1	22Oct14
    """)

def test_keep_open_range(run, short_ps):
    run("keep 1,6-", stdin=short_ps, stdout="""
        UID	TTY	TIME	CMD
        0	??	0:12.72	/usr/libexec/UserEventAgent
        0	??	0:26.80	/usr/libexec/kextd
        0	??	6:27.11	/usr/sbin/notifyd
    """)
