# Testing: A keep-alive server must end a connection the client asked to close

**Date**: 2026-11-05
**Lesson**: A server loop on `std.http.Server` that calls `receiveHead` again after every answer hangs a client that sent `Connection: close` and reads to end of stream: std writes `connection: close` in the answer but leaves closing the socket to the caller.

**Why**: `Request.respond` reads `head.keep_alive` only to choose the header and whether to discard the body; the loop around it decides whether to read another request. A test client that reads until EOF (the simplest whole-response reader) then waits for a close that never comes, and the server thread waits for a request that never comes.

**What Happened**: tools/perf_bench's server tests hung in lane perf0's first pool run: the client in `fetchRaw` and the connection thread both blocked in `readVec` (`sample` showed both stacks). Each hang cost the launcher's 300 s per-test timeout, and the launcher's alone re-runs repeated it until the job was killed by hand (its maker, launcher and test pids, each exactly).

**Fix**: Read `request.head.keep_alive` before answering (the answer invalidates the head's strings, not the bool, but read it first anyway) and return from the connection loop after answering when it is false. For red/green of new network tests pass `-Dlaunch-timeout=60`, so a hang costs a minute, not five per attempt.

**Takeaway**: **Honour `Connection: close` yourself: std's server answers with the header but the loop must end the connection. Run new socket tests with a short launcher timeout.**
