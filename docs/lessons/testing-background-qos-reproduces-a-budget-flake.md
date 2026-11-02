# Testing: Background QoS reproduces a budget flake; a race between two threads needs the delay injected

**Date**: 2026-11-02
**Lesson**: `taskpolicy -b` (macOS background QoS) makes a fixed time budget fail on demand, but it slows every thread of the process alike, so it does not reproduce an ordering race between two of them. For that, inject the delay at the race point.

**Why**: A test that gives work a fixed budget, such as `runEventLoopBlocking(10)` before an assertion, fails whenever the process gets too little CPU. Background QoS throttles the process and its children, so a budget that holds on an idle host stops holding. A race between the test thread and a server thread in the same process is different: both slow down together, and the order between them barely moves.

**What Happened**: tests/html xhr_document_abort_task_test's "Location replacement" gave a frame's navigation 10 ms of turns. At normal QoS on a host at load 15-20 it passed. Under `taskpolicy -b` (passed through the launcher, batch 1, 4 at once) main's test failed 13 of 40 runs and 17 of 30, every time with the gate's message "expected 0, found 1". The fixed test (turn until the loop settles) passed 200/200 and its file 390/390. The same setting did not reproduce ka2_kept_fetch_test's flake (200/200 on main), which was a race between the test thread and its server's thread. A copy of main's test with `clock.sleep(20 ms)` at the race point failed every run, and the fixed test with the same pause passed.

**Fix**: For a budget flake, run the test in a loop under `taskpolicy -b`, prefixed to `test_launcher <exe> --filter=<name> --batch=1` (its children inherit the policy). Run it as a pool measurement (crane-pool.sh wpt, crane-measure.sh run) within the job's token share, and count failures for main and for the fix. For an ordering race, make a temporary copy of the test with a pause where the losing thread would be preempted, and show RED on main and GREEN on the fix.

**Takeaway**: **Slow the whole process to break a time budget; pause one thread at the race point to break an ordering bet - and count both, main against the fix.**
