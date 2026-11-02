# Testing: A request is on the wire when its fetch starts, so "the server has nothing yet" is a race

**Date**: 2026-11-02
**Lesson**: Crane sends a new transfer's request as the fetch starts (NetworkScheduler.kick), so a test that asserts the server has not seen the request yet is betting that it runs before the server's thread does.

**Why**: kick runs the transfer forward until its request is sent, by design (architecture-single-threaded-networking-must-send-the-request.md). When `start` returns, the bytes are already in the server's socket. What happens next depends only on the scheduler: the server thread accepts, reads and counts, while the test thread runs on to its next line.

**What Happened**: tests/html ka2_kept_fetch_test's first test asserted `server.count("/ka2/beacon") == 0` right after `keepalive_fetch.start`, with the comment "Nothing has been sent: the network is pumped by the event loop". It was FLAKY in two lanes' gates ("expected 0, found 1"), and passed 200 of 200 runs at a host load of 17, even at background QoS. A probe that turned no event loop at all saw the request reach the server in 20 of 20 runs, 0.1 to 10 ms after `start` returned. Main's test injected with a 20 ms pause at that point (what a loaded host does to the test thread) failed every run. The pause also exposed two other bets in the file: `turnUntil`'s budget of 100 turns of 20 ms (2 s), and a route answering after `delay_ms = 1500` on which three tests relied for "the answer is still to come".

**Fix**:
1. Assert what is deterministic, on Crane's side. Only the loop's network step delivers, so before any turn the dispatch has heard nothing and ended nothing, and the fetch is live (`inFlight() == before + 1`).
2. Wait on conditions. `turnUntil` is bounded at 30 s, and only to stop a test that never meets its condition.
3. Let the server gate the answer. module1_http_server's `held` routes count the request and answer only on `release(path)` or `stop()`. A fixture test checks both cases, including a stop with nothing released.
With the 20 ms pause injected, the fixed test passes. At background QoS it passed 200/200, and the whole file 200/200.

**Takeaway**: **Once a request is sent at start, "not sent yet" is never a fact a test can assert; assert the client's state (nothing delivered before a loop turn), and let the server announce and gate the rest.**
