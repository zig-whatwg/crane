# Testing: An HTTP client that reads to EOF hangs on a keep-alive server

**Date**: 2026-11-23
**Lesson**: A test's HTTP/1.1 client must stop reading at the end of the response (Content-Length, or chunked's last chunk), not at the connection's close: a server that keeps the connection open - Chrome's DevTools HTTP server, net::HttpServer - never sends EOF, and the read waits forever.

**Why**: HTTP/1.1 connections are persistent by default (RFC 9112 9.3). Crane's own remote end answers with `Connection: close`, so a client written against it and reading to EOF works there and nowhere else.

**What Happened**: Lane cdpd1's two Chrome proofs (the trace recorded against Chrome for Testing 157, and Chrome DevTools' front end on Crane) both timed out at the test launcher's 300 s, three runs each, with no output: tests/devtools/cdp_client.zig's `httpGet` read /json/list and /json/version from Chrome until EOF. Progress lines on stderr and a direct run of the test binary under a time limit (.cdpd1/direct.sh) showed where it stopped; reading to the Content-Length fixed both.

**Fix**: `httpGet` stops once the head and Content-Length bytes of body are in (`complete`), and still ends at EOF for a server that closes.

**Takeaway**: **A protocol helper written against your own server inherits its habits: test it once against the real counterpart before trusting a silent timeout, and give a long-running proof progress output so a hang names its step.**
