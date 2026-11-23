# Architecture: A new curl error is refined from curl's message, inside the platform ratchet

**Date**: 2026-11-22
**Lesson**: To report a network failure as Chromium names it, when curl's code does not tell it apart, refine the error that curl_error.mapCurlError already returns using the transfer's error-buffer message. Do it in a helper with no curl identifiers, and pin each message with a test that sends the real response through the vendored curl.

**Why**: lint-platform counts every curl identifier and every curl-wrapper member per file outside src/platform/, and its baseline only goes down. A new `CURLE_*` constant, a second reference to an existing one, or a new curl_error function called from curl_backend.zig all fail the gate. Two cases where curl's code is not enough:
- curl fails a chunked body whose framing does not parse with CURLE_RECV_ERROR, a reset's code. Only the message ("... in chunked-encoding", "chunk hex-length ...", lib/http_chunks.c) tells them apart.
- A body cut short is CURLE_PARTIAL_FILE, which mapCurlError leaves unknown. Chromium separates ERR_CONTENT_LENGTH_MISMATCH from ERR_INCOMPLETE_CHUNKED_ENCODING, and curl's messages separate them too (sendf.c, transfer.c, http_chunks.c).

**What Happened**: Lane fw2's first version added `mapTransferError` and `CURLE_PARTIAL_FILE` to curl_error.zig and called the new function from curl_backend.zig. lint-platform failed it on two keys ("allowed 0, found 2").

**Fix**: curl_backend.zig reads `curl.errorBufferMessage` once per failure path, reusing the value in its log line, so the count stays the same. It passes `curl_error.mapCurlError(result)` (an existing reference) and the message to a private `refineTransferError(err, message)` that names no curl symbol. tests/fetch/fw2_chunked_errors_test.zig serves each malformed response over loopback and asserts Chrome's errorText by both scheduler paths. A curl update that rewords a message fails it. Its expectations are texts (NetError.fromNetwork(err).text()), so the test compiles against a tree without the new errors, and its red is an assertion, not a compile error.

**Takeaway**: **Under a ratchet lint, add behaviour without new counted identifiers. Refine what an existing call returns, and pin any message text you rely on with a test through the real library.**
