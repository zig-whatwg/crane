# Testing: A loopback server behind the Browser's proxy counts module fetches

**Date**: 2026-10-18
**Lesson**: Most module map behaviour shows only as a number of requests. A refetch after a failure, a joined fetch, and a modulepreload reused by import() all look like this. A loopback HTTP server that a Browser's manual proxy points at keeps the page's own origin (http://module1.test/) and counts requests per path. That makes each of those behaviours a plain Zig test. `tests/html/module1_http_server.zig` is the helper.

**Why**: Blob and data URLs cannot fail once and then succeed, and they never reach a server, so they cannot show whether a failure was cached or a fetch was joined. WPT shows it with its Python handlers (module-fetch-tester.py, serve-custom-response.py). A Zig unit test needs the same counter, without the WPT server.

**What Happened**: The module1 tests needed several kinds of route:
- one that fails its first N requests;
- one that waits, so that concurrent imports overlap;
- one that echoes the Accept header (the "text" destination's `text/plain,*/*;q=0.5`);
- one that serves a module whose default export is the request's Referer, so a referrer policy can be read from script.

The pattern came from mx2_data_worker_test.zig's proxy. Each connection is answered on a thread of its own, so that a delayed answer does not hold back the requests behind it. `stop()` waits for those threads before it frees the routes they read.

**Fix**: `Browser.init(..., .{ .proxy = .{ .manual = .{ .http = server.proxyUrl(...), .no_proxy = "" } } })`, `navigateWithOptions(page_url, .window, .{ .skip_load = true })`, then `loadHTML`. Every response carries `Cache-Control: no-store` and `Access-Control-Allow-Origin: *`, so no HTTP cache and no CORS rule hides a request.

**Takeaway**: **When the behaviour under test is "how many times was this fetched", give the test a server that counts - a request count is the only observable that tells a cache hit from a refetch.**
