# Testing: A cap that counts what is still tearing down refuses the next one on a loaded host

**Date**: 2026-11-27
**Lesson**: When a bound on live things (threads, connections, sessions) also counts things already told to go, a burst followed by real work makes the real work wait for teardown. Refuse at the cap, and that work fails whenever teardown lags, which happens only on a busy host. Wait at the cap for something being torn down to finish, and test with a burst far larger than the bound.

**Why**: The MCP HTTP server lists every accepted connection until its worker thread has unlisted it, and it bounds that list (`max_connections + 2 x max_pending_connections`) to bound threads. A pending connection evicted for a newer one is shut down at once, but it stays listed until its thread runs and exits. On a quiet host that takes microseconds. On a loaded host the thread may not run for milliseconds, and by then the list is at the cap.

**What Happened**: Lane mcp3 batch A's test "twelve idle sockets that never authenticate cannot lock the agent out" passed on Linux, and on macOS passed 10/10 batched. Under `test-verify`, run alone, it passed 4/5 on chat.local at load 17, and 4/5 again on chat2 with forty idle sockets (red at 905c1ce39). The agent's own request got its connection closed with no response. The acceptor had refused it because the list was full of evicted connections that had not exited yet. The test's twelve sockets were barely over the cap of ten, so the race needed a slow scheduler to show.

**Fix**:
1. At the cap, wait instead of refusing. The live entries are at most the slots the bound protects (authenticated plus pending), so every entry over them is already shut and on its way out. `retire()` bumps a futex word, and the acceptor waits on it in 50 ms slices until stop (src/devtools/mcp/http.zig `admit`).
2. Make the test's burst far larger than the bound: forty sockets against a cap of ten. A burst that is just over the cap needs a slow host to fail, and so passes in most gates.
3. Before calling a timing-dependent test fixed, prove it under load: `test-verify` repeated (50 runs alone on chat.local, plus the TSan variant), with the counts quoted.

**Takeaway**: **A bound must not count what is already leaving - or, if it must, wait for it to leave instead of refusing the newcomer; and size a test's burst well past the bound, or the race only shows on a loaded host.**
