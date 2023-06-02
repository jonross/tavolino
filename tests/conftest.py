import pytest
import subprocess as sub

@pytest.fixture
def run():
    def _run(args, stdin="", stdout="", stderr=""):
        p = sub.Popen(["tl"] + args.split(" "), stdin=sub.PIPE, stdout=sub.PIPE, stderr=sub.PIPE, universal_newlines=True)
        actual_stdout, actual_stderr = map(norm_ws, p.communicate(stdin.lstrip()))
        expected_stdout, expected_stderr = map(norm_ws, [stdout, stderr])
        assert actual_stderr == expected_stderr
        assert actual_stdout == expected_stdout
    return _run

def norm_ws(text):
    if "\n" not in text:
        return text.strip()
    lines = (line.strip() for line in text.strip().split("\n"))
    return "\n".join(lines) + "\n"

@pytest.fixture
def short_ps():
    return """ 
      UID   PID  PPID   C STIME   TTY           TIME CMD
        0    11     1   0 22Oct14 ??         0:12.72 /usr/libexec/UserEventAgent
        0    12     1   0 22Oct14 ??         0:26.80 /usr/libexec/kextd
        0    14     1   0 22Oct14 ??         6:27.11 /usr/sbin/notifyd
    """

@pytest.fixture
def long_ps():
    return """ 
      UID   PID  PPID   C STIME   TTY           TIME CMD
        0     1     0   0 22Oct14 ??        25:02.89 /sbin/launchd
        0    11     1   0 22Oct14 ??         0:12.72 /usr/libexec/UserEventAgent
        0    12     1   0 22Oct14 ??         0:26.80 /usr/libexec/kextd
        0    14     1   0 22Oct14 ??         6:27.11 /usr/sbin/notifyd
        0    15     1   0 22Oct14 ??         1:36.96 /usr/sbin/securityd
        0    16     1   0 22Oct14 ??         0:09.88 /usr/sbin/diskarbitrationd
        0    17     1   0 22Oct14 ??        11:31.90 /usr/libexec/configd
        0    18     1   0 22Oct14 ??         3:01.72 /System/Library/CoreServices/powerd.bundle/powerd
        0    19     1   0 22Oct14 ??         0:27.40 /usr/sbin/syslogd
    """

@pytest.fixture
def long_ps_tsv():
    return """UID	PID	PPID	C	STIME	TTY	TIME	CMD
0	1	0	0	22Oct14	??	25:02.89	/sbin/launchd
0	11	1	0	22Oct14	??	0:12.72	/usr/libexec/UserEventAgent
0	12	1	0	22Oct14	??	0:26.80	/usr/libexec/kextd
0	14	1	0	22Oct14	??	6:27.11	/usr/sbin/notifyd
0	15	1	0	22Oct14	??	1:36.96	/usr/sbin/securityd
0	16	1	0	22Oct14	??	0:09.88	/usr/sbin/diskarbitrationd
0	17	1	0	22Oct14	??	11:31.90	/usr/libexec/configd
0	18	1	0	22Oct14	??	3:01.72	/System/Library/CoreServices/powerd.bundle/powerd
0	19	1	0	22Oct14	??	0:27.40	/usr/sbin/syslogd
    """

@pytest.fixture
def utils():
    return TestUtils()

class TestUtils:

    def run(self, args, stdin="", stdout="", stderr=""):
        p = sub.Popen(["tl"] + args.split(" "), stdin=sub.PIPE, stdout=sub.PIPE, stderr=sub.PIPE, universal_newlines=True)
        actual_stdout, actual_stderr = map(norm_ws, p.communicate(stdin.lstrip()))
        expected_stdout, expected_stderr = map(norm_ws, [stdout, stderr])
        assert actual_stdout == expected_stdout
        assert actual_stderr == expected_stderr


