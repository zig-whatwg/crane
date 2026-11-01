# Debugging: A streamed response's head carried no connection timing

**Date**: 2026-10-31
**Lesson**: The network layer built a streamed transfer's head (`Transfer.head`) without reading curl's connection measurements, so every streamed response - every navigation - said "fresh connection" with DNS, connect and TLS at 0 ms. Before trusting a transport flag in a diagnosis, check that the path you are on sets it.

**Why**: `Transfer.finish` (a whole response) read CURLINFO_NAMELOOKUP/CONNECT/APPCONNECT/PRETRANSFER_TIME and CURLINFO_NUM_CONNECTS; `Transfer.head` (a stream's response, handed on when its headers are in) read none of them, and NetworkResponse's defaults are `connection_reused = false` and zero times. HTTP-network fetch then timed a reused connection as a fresh one: its secureConnectionStart was the network start, a second clock reading 0.1-0.2 ms after fetchStart.

**What Happened**: navigation-timing/secure-connection-start-reuse.https.html failed 16 of 50 isolated runs ("secureConnectionStart value of 0.1 does not equal 0") on frozen main 0aa6c6c8cf. A 2026-10-14 diagnosis ([A reuse test can open fresh connections](debugging-a-reuse-test-can-open-fresh-connections.md)) logged the backend's flag for the innermost navigation, saw "fresh" in all 100 runs, and concluded the test's premise was false. Lane flaky4 logged curl itself (CURLINFO_CONN_ID, CURLINFO_NUM_CONNECTS) beside the flag: the innermost navigation ran on the interim frame's connection (conn 1, num_connects 0) in every run, while the flag said `reused=false` and every time 0 - the flag was never measured on the streamed path. Whether the test passed depended only on whether fetchStart and the network start fell in one 100 us tick.

**Fix**: `ConnectionMeasures.of(transfer)` (src/fetch/network/curl_backend.zig) reads the five measurements once for both `finish` and `head`; tests/fetch/network_scheduler_test.zig "a streamed transfer's head says whether its connection was reused" pins it against a keep-alive endpoint of the test server.

**Takeaway**: **A diagnostic that reads a derived flag inherits the flag's bugs: log the source's own identifiers (the connection id, the connect count) beside it, and the "premise" may turn out to be the bug.**
