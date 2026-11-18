# Workflow: A new curl option goes through kit/curl, not src/fetch/network

**Date**: 2026-11-18
**Lesson**: lint-platform counts every `curl.*` symbol in src/fetch/network/curl_backend.zig against a baseline that only goes down, so a new option set there fails `zig build test`.

**Why**: The network is moving behind the platform protocol (kit/curl). Until fetch's transfers move, curl_backend.zig keeps making its easy handles, but the options it sets are the platform's: `kit_curl.options.apply`, `forbidReuse`.

**What Happened**: Fetch's 421 retry needs a new connection (CURLOPT_FRESH_CONNECT). `curl.easy_setopt(handle, curl.CURLOPT_FRESH_CONNECT, 1)` in curl_backend.zig compiled and its unit tests passed, but the test step failed: "platform boundary: 1 key(s) above the baseline ... curl.CURLOPT_FRESH_CONNECT: allowed 0, found 1".

**Fix**: add the setter to src/platform/kit/curl/options.zig (`freshConnect(handle)`, with its option id and a unit test beside `forbidReuse`'s) and call `kit_curl.options.freshConnect(handle)` from curl_backend.zig - no new key.

**Takeaway**: **Run the narrow test step with its lints (`-Dspec=<dir>` still runs them) before the full gate, and put any new curl option in kit/curl/options.zig from the start.**
