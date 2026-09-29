# Architecture: curl knows a transfer's HTTP version only from its response

**Date**: 2026-09-28
**Lesson**: `CURLINFO_HTTP_VERSION` reads the version from the response's status line, so it cannot say, before a request is sent, whether the connection is HTTP/2. The TLS session can: ALPN is settled when `CURLOPT_PREREQFUNCTION` runs.

**Why**: Fetch's HTTP-network fetch step 8.3 refuses a body with a null source (a ReadableStream) on an HTTP/1.x connection. The refusal must come before any of the request goes out. With `CURL_HTTP_VERSION_2TLS`, whether an https connection is HTTP/2 is decided by ALPN during the TLS handshake. In curl 8.18, `data->info.httpversion` - what `CURLINFO_HTTP_VERSION` returns - is set in `lib/http.c` (around line 3666) when the status line is parsed. Until then it reads `CURL_HTTP_VERSION_NONE`, or a stale value from the handle's last transfer.

**What Happened**: The first plan for 8.3 over HTTP/2 was to check `CURLINFO_HTTP_VERSION` in the upload's read callback before the first chunk, and abort on 1.x. Reading `lib/getinfo.c` and `lib/http.c` showed the check could never see the connection's version at that point. On a fresh handle it would refuse every upload; on a reused handle it would pass or refuse on the previous transfer's version.

**Fix** (c20, `src/fetch/network/curl_backend.zig`):
- A request with a null-source body carries `NetworkRequest.require_http2`. Only such a request gets `CURLOPT_PREREQFUNCTION`; every other https request still falls back to HTTP/1.1.
- curl calls the pre-request callback after the connection and its TLS handshake are up, reused connections included, and before anything of the request is sent.
- The callback asks the TLS library: `CURLINFO_TLS_SSL_PTR` hands out the backend's session, and for mbedTLS `mbedtls_ssl_get_alpn_protocol()` names the protocol ALPN chose. If it isn't `"h2"`, the callback returns `CURL_PREREQFUNC_ABORT` and the transfer ends with `CURLE_ABORTED_BY_CALLBACK`, a network error with nothing sent. Any other TLS backend fails closed, and build.zig's `tls_backend` names the function to extend.
- A cleartext `http:` URL is refused before the network: Crane never does h2c, so that connection is always HTTP/1.x.

**Takeaway**: **Before relying on a curl info field at a point in the transfer, find where curl sets it. A value that describes the response is not available while the request is being sent.**
