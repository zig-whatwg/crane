# Testing: A network test takes its timing from the server, not the clock

**Date**: 2026-10-01
**Lesson**: A unit test that stages a network race with sleeps ("sleep 40 ms, then the response is half there") passes alone and fails under load, because load moves the server's thread and the client's connect, not the test's clock.

**Why**: `async_fetch_test`'s "catchUp reads out a response that had started arriving during a long task" slept 40 ms as the long task and expected the status line of `/split-head/150` to be in the socket by then. Two things outside the test decide that: the scheduler's `kick` gives a new transfer only four 1 ms rounds to connect and send, and the test server's thread must be scheduled to accept, read and write. On a loaded machine either can take longer than 40 ms. Then nothing has started arriving, `catchUp` correctly returns at once (its own rule: it waits only for a response already arriving), and the test fails on `response orelse return error.TestUnexpectedResult`. It failed twice in gate runs beside sweeps and passed 6 of 6 alone.

**What Happened**: The test checked a real property, but the property's precondition - "the response has started arriving and its header block has not" - was produced by wall-clock margins.

**Fix**: Make the server state the moments (tests/fetch/test_server.zig `/split-head`): it writes the status line and sets `headStarted`, then holds the rest until the test calls `releaseHead`. The test pumps until the fetch `isArriving()` (which only sends the request and reads the status line - the rest is held), asserts the timeout's view (arriving, no response), releases, and calls `catchUp` with a budget that only has to outlast the server's thread - `catchUp` returns the moment the fetch is over, and its budget bound has a test of its own. Measure the old and new test under an injected server delay: the old fails every time, the new passes every time.

**Takeaway**: **When a test stages a race, let the peer it controls announce and gate each step; a sleep is a bet on the machine's load.**
