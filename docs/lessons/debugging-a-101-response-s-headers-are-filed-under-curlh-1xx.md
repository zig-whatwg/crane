# Debugging: A 101 response's headers are filed under `CURLH_1XX`

**Date**: 2026-09-26
**Lesson**: `curl_easy_header` with only `CURLH_HEADER` finds nothing on a WebSocket upgrade response.

**Why**: curl files the headers of a 1xx response under `CURLH_1XX`.

**What Happened**: The chosen subprotocol read as absent, so a wrong one could not be detected.

**Fix**: Ask for `CURLH_HEADER | CURLH_1XX` (lane/websockets 3bddabb58).

**Takeaway**: **A header curl says is missing may be filed under another origin bit.**
