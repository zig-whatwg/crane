# Testing: A passing cost test prints nothing - record the green numbers on purpose

**Date**: 2026-11-10
**Lesson**: The test launcher keeps a child's output only for a test that does not pass, so a cost test that prints its measurement and then passes shows nothing in the gate log: write every case before the first assertion fails, and get the green numbers from a deliberate failing run.

**Why**: tools/test_launcher runs each test in a child process and writes the child's output to `tmp/test-launch/<suite>.log` only for FAIL, ORDER-DEPENDENT, FLAKY and LAUNCHER-ERROR verdicts. `zig build test` without `--summary` prints no Build Summary either when everything passes. A red run shows the numbers because the test fails; the green run that the merge report needs shows only an exit status.

**What Happened**: Lane lis1's tests/html/lis1_listener_storage_test.zig counts the bytes a Browser's allocator keeps for one listener and one event handler on 64 elements. Its first red run printed only the first case (485 B per listener) because `report` returned the error at once, so the handler's red figure (1,117 B) needed a second red run after `report` was changed to count the cases over their limit and fail once at the end. The green run then ended with `HTML-RC=0` and no figures: they came from a one-off run with the final check forced to fail (an uncommitted edit, restored as soon as crane-remote had synced the mirror).

**Fix**:
1. In a cost test, print every case, count the ones over their limit, and fail once after the last.
2. Record the red numbers from the red run (it fails, so it prints).
3. For the green numbers, make the final check fail in an uncommitted edit, start the pool job, and restore the file when crane-remote prints its job pid (the mirror is synced by then); or read them from a measurement that does not depend on the test's verdict.

**Takeaway**: **The launcher shows a test's output only when it does not pass: print every case before failing, and plan how the green figures will be seen.**
