# Testing: Never close a listener under its accept thread - wake it, join it, then close

**Date**: 2026-11-02
**Lesson**: Closing a listening socket to unblock another thread's accept() is a race: an accept() that begins after the close gets EBADF, which Zig 0.17's Io.Threaded treats as a programmer bug and panics on in Debug, and the closed descriptor's number may already belong to another file.

**Why**: The stop has to reach a thread that may be anywhere: not started yet, blocked in accept(), or between two accepts. Closing the descriptor reaches the blocked case. In the others, the thread's next accept() runs on a closed descriptor, or on whatever reused its number. `netAcceptPosix` maps BADF to `errnoBug`, which calls `std.debug.panic` when `is_debug`.

**What Happened**: tests-fetch "TestServer - WebSocket URL" starts a server and stops it at once. It was FLAKY in lane tstate1's gates with a BADF panic in the server's accept loop. The shape (set a flag, `server.deinit`, join) was copied into 14 loopback fixtures across tests/fetch, tests/html, tests/service_worker and tests/websocket. Each test directory is its own executable and cannot import a file outside its root, so each fixture carried its own copy.

**Fix**: `tests/support/loopback_listener.zig` (module `loopback_listener`, imported by every test root through build.zig's addTestRoot). `stop()` sets the flag and wakes accept() with a loopback connection of its own. `accept()` returns null once stopping and closes whatever connection woke it. The owner joins the thread, then calls `close()`. Every fixture now uses it: `while (self.listener.accept()) |stream|`, and `stop(); join(); close()`. The stress test (tests/fetch/loopback_listener_test.zig) stops 3,000 accept loops, at once after start and with a client racing the stop.

**Takeaway**: **A thread blocked on a descriptor is stopped by giving it something to return, not by closing the descriptor under it; close only after the join.**
