# Testing: A "blocked" request that passes because the connection was refused hides a missing check

**Date**: 2026-11-08
**Lesson**: A WPT subtest that expects a request to be blocked also passes when the request goes out and fails. Log the transport's result for each connection: only a block that makes no connection proves the check is there.

**Why**: websockets/Create-blocked-port.any.js expects an error event from a WebSocket to each of Fetch's 83 bad ports. Crane's handshake preparation (WebSocket.zig prepareHandshakeRequest) asked CSP and Mixed Content, but never Fetch's "should request be blocked due to a bad port" (main fetch step 7). Every blocked socket resolved its host and connected. Most ports refused, and the subtest saw an error, so all 83 blocked-port subtests had passed for as long as the file had run. Crane's port list was also out of date: it lacked 0, 4190 and 6679 of the table's 83 rows.

**What Happened**: Lane flaky5 was chasing the file's ?wss "Basic check" flake. A diagnostic build logged curl's result, status and connect count for every WebSocket handshake. Over 60 runs at --parallel=8 --load=4 it recorded:
- 29,517 "Could not connect to server" on blocked ports;
- 240 wss://web-platform.test:22 handshakes that reached the host's sshd and failed at TLS;
- 120 ws://...:22 handshakes that read sshd's banner;
- 3 "Could not resolve hostname" failures in the lookup burst.
Each run made 83 x 6 real lookups and connection attempts that no browser makes. The Basic check flake itself was not explained by this; it stays open.

**Fix**: prepareHandshakeRequest asks main_fetch.shouldBlockDueToBadPort first, as step 7 lists it, and the list now has the table's 83 rows. The red test is tests/websocket/flaky5_bad_port_test.zig. It runs a listener on a bad port above 1024 that must see no connection. On the unfixed tree it failed "expected 0, found 1". The listener binds exclusively, because copies of a test that share a port through SO_REUSEPORT steal each other's connections in verify mode.

**Takeaway**: **When a test expects a request to be blocked, check that nothing reached the network - a listener that must stay silent, or the transport's own log - because a refused connection passes the same subtest as a missing check.**
