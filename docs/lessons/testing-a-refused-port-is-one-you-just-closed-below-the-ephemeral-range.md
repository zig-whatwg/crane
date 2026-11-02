# Testing: A refused test port is one you just closed, below the ephemeral range

**Date**: 2026-11-02
**Lesson**: A fixed "nobody listens here" port in the ephemeral range is not refused for long, and a port held by a socket that is bound but not listening is not refused on macOS at all.

**Why**: macOS hands out ephemeral ports in 49152-65535 and Linux in 32768-60999, both to listeners on port 0 and to connections' source ports. A port in those ranges can be taken by any test server in any process on the host, and a connection's own source port can even be its destination (a TCP self-connect). On macOS, a SYN to a port whose only socket is bound but not listening is dropped rather than answered with RST, so the connect times out instead of being refused.

**What Happened**: tests/fetch network_integration_test's "connection refused" used 127.0.0.1:59999. At batch 1 in a launcher survey, something answered on that port, and the test then failed with a leak on the response's path. With a 404 listener on 59999, main's test fails every run ("expected error.ConnectionRefused, found" the 404 response). The first fix held the port with a bound socket that never listens: on macOS the request then timed out after 7.8 s (curl error 28, error.RequestTimeout).

**Fix**: `refusingPort()` takes the first port from 20000 up that the test can bind, then closes it before the request. A successful bind shows no socket held the port a moment before. Because the port is below every ephemeral range, no port-0 listener and no source port can take it in the meantime. Result: 200/200 at batch 1 at background QoS, and it passes with listeners on 59999 and on 20000 (it moves on to the next port). The same applies to a fixture that must stay unanswered: tests/html xhr_document_abort_task_test's `Unanswered` is a listener that never accepts, not a refused port, because the scheduler retries a refused connection (100 + 200 ms) and then fails the request.

**Takeaway**: **Never hard-code a "closed" port: bind one below the ephemeral ranges, close it, then connect - and on macOS do not expect a bound-but-not-listening socket to refuse.**
