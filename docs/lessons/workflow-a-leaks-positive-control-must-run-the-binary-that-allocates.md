# Workflow: A leaks positive control must run the binary that allocates, and a missing summary is a failed control

**Date**: 2026-10-29
**Lesson**: `leaks --atExit -- /usr/bin/python3 ...` and `leaks --atExit -- <Homebrew python3> ...` printed no leak summary at all for a deliberate `malloc`, so a script that greps the summary line printed nothing - and a missing line reads like a quiet pass.

**Why**: `/usr/bin/python3` is a launcher that hands over to the Xcode or Command Line Tools Python, and `leaks` produced no report for it; the Homebrew `python3` run printed no summary line either (its full output was not kept, so why is unknown). Either way the "N leaks for M total leaked bytes" line the control is read from never appeared. A control is only evidence when it prints that line with the leak in it. The runner arms of the same check reported "0 leaks for 0 total leaked bytes", which is exactly what an unqualified detector also says.

**What Happened**: Lane refcount8's final-tip proof (2026-10-29, chat2.local) ran `leaks --atExit -- <python3> -c 'import ctypes; ctypes.CDLL(None).malloc(131072)' | grep -E "leaks for|total leaked" | head -2 | sed 's/^/positive control: /'`. The log had no "positive control:" line, the two runner arms said 0 leaks, and the proof looked complete. A rerun on `/usr/bin/python3` printed only MallocStackLogging chatter, detector exit 0. The control the Codex rows had already proven (Q88/Q110, row 126's payload) runs the Python.app executable directly and found the leak at once: 1 leak for 14,336 bytes, `ROOT LEAK: <malloc in ffi_call_SYSV>`, detector exit 1.

**Fix**:
1. Wrap the executable that allocates, not a launcher:
   `/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python` (or the Command Line Tools copy), with a script that sets `libc.malloc.restype = ctypes.c_void_p`, calls `libc.malloc(12345)`, discards the result and sleeps 2 s.
2. Read the control's own summary line and its detector exit (1 when it finds a leak). Treat no summary, or "0 leaks", as a FAILED control: stop and fix the method before trusting any runner arm.
3. Run the runner arms after the control, with the same `leaks` on the same host.

**Takeaway**: **A positive control passes only when its summary line shows the deliberate leak - run the binary that calls malloc (Python.app, not `/usr/bin/python3`), and treat silence as failure.**
