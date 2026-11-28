# Testing: A wall-clock upper bound fails under pool load - assert on what the code recorded

**Date**: 2026-11-27
**Lesson**: Host load can only lengthen wall time. A test's lower bound on elapsed time survives a loaded pool host, but an upper bound ("the restored run is faster than 0.75 x the throttled one") or a ratio between two timed runs does not. Either run can be slowed by whatever else the host runs, so the test fails without any fault in the code. Assert on what the code under test itself did (a counter it keeps, a record of what it paused), and keep wall-clock checks to lower bounds. Retrying the timed run only hides the flake.

**Why**: `mcp2_cpu_throttling_test`'s "Browser JS setTimeout chain slows under EventLoop CPU throttling and restores at rate 1.0" timed three setTimeout chains and asserted `restored < 0.75 x throttled` and `throttled >= 2 x unthrottled`. At rate 1.0 the event loop runs no throttle code, so the restored chain's time is all host scheduling.

**What Happened**: Lane mcp3 batch B's Linux TSan verify failed the test once. Ten TSan verifies on server1 then gave 9 passed and 1 failed, at load averages up to 29: 41.9 ms unthrottled, 170.6 ms at 4x, 193.8 ms restored. A first fix gave the restored chain up to three tries. The integrator had it reverted: a retry hides a flake and does not fix it (the user's rules: flakes are bugs; no workarounds, fix the cause).

**Fix**:
1. Give the code a record of what it did: `EventLoop.cpu_throttle_paused_ns`, the total time the throttle paused the loop.
2. Assert on that record: the 4x chain paused at least 100 ms (it owes 3 x 40 ms), and the restored chain paused nothing.
3. Keep only the wall-clock lower bounds (unthrottled >= 30 ms, throttled >= 130 ms), which load cannot break. Drop the upper bound and the ratio.

**Takeaway**: **Never bound a test's wall time from above, or compare two timed runs, on a shared host: assert on what the code under test recorded, keep wall-clock checks to lower bounds, and never retry a timed run to make it pass.**
