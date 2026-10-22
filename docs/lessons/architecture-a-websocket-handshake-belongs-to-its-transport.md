# Architecture: A WebSocket handshake belongs to its transport

**Date**: 2026-10-20
**Lesson**: Expose the selected transport's verified response, and keep connection selection distinct from response validation.

**Why**: HTTP/1.1 WebSockets use GET, Upgrade and 101; RFC8441 uses an existing eligible HTTP/2 session, extended CONNECT and a successful CONNECT response. Accepting 200 on the existing GET path does not implement HTTP/2 WebSockets.

**What Happened**: Crane's platform WebSocket operation was an unused stub, while src/websocket owned curl directly and required 101. Curl 8.18.0's public WebSocket API handles HTTP/1.1; enabling nghttp2 alone does not supply an RFC8441 stream. Chromium's HttpStreamFactory::Job only selects an existing HTTP/2 session for WebSockets. Gecko's TryDispatchExtendedCONNECTransaction distinguishes a session waiting for SETTINGS from one that lacks CONNECT support, and falls back only in the latter case.

**Fix**: Move native handles, I/O and copied headers under the platform. Return a verified handshake containing the actual HTTP version, status and response fields, including failed-handshake cookies. Keep cookie policy, subprotocol validation and WebSocket state above it. Drive the owned transport from the existing owned timer and cancel synchronously on release. Complete shared-session selection before claiming RFC8441 support; a status test alone proves only response policy.

Browser references (design only, no copied code):
- https://github.com/chromium/chromium/blob/main/net/http/http_stream_factory_job.cc — DoInitConnectionComplete and DoCreateStream.
- https://github.com/chromium/chromium/blob/main/net/websockets/websocket_http2_handshake_stream.cc — SendRequest, Upgrade and ValidateResponse.
- https://github.com/mozilla/gecko-dev/blob/master/netwerk/protocol/http/nsHttpConnectionMgr.cpp — TryDispatchExtendedCONNECTransaction.

**Takeaway**: **A versioned handshake result is necessary, but only a real negotiated stream establishes the WebSocket.**
