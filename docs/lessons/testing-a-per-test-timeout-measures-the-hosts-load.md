# Testing: A per-test timeout measures the host's load, not only the test

**Date**: 2026-11-01
**Lesson**: Set a per-test timeout from the tests' times under the load the gate really runs with, not from their times alone: under a full `zig build test`, Crane's Debug tests took up to three times as long as alone, and a 60 s timeout failed tests that take 20 s.

**Why**: `zig build test` compiles the remaining test executables while the finished ones run, and the launcher keeps a test process on every core. A test's wall time then depends on what shares the host with it. The old build runner had no timeout, so nothing ever measured this; the first timeout to run did.

**What Happened**: The first `zig build test` through tools/test_launcher (lane tlaunch2, chat.local, 14 test processes plus compiles) used the launcher's 60 s default. Ten tests timed out, eight of them in their alone re-runs too, and were reported FAIL or FLAKY. Run alone afterwards, four at a time, with a 1,200 s timeout, all ten passed: three in 19-28 s (editing3_wrap, ce_form_owner_reset, bx1_transform_composition), the rest in 50-138 s. The "alone" re-runs had not been alone: they ran while the other suites still filled the host.

**Fix**: build.zig's default per-test timeout is 300 s (`-Dlaunch-timeout`), and the tests over 45 s alone are listed as slow in `suite_configs` (4x: Chromium's and V8's SLOW), each with its measured time. The timeout's job is to turn a hang into a named failure, which 300 s still does.

**Takeaway**: **Measure a timeout's tests under the gate's own load before trusting it; a test that "times out alone" during a busy build may only be slow.**
