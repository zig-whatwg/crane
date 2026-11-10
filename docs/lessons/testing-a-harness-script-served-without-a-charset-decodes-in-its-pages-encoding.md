# Testing: A harness script served without a charset decodes in its page's encoding

**Date**: 2026-11-09
**Lesson**: When the WPT runner's testharnessreport.js moved from an engine hook to a `wpt serve` alias (lane wptcfg batch 1), it went out as "text/javascript" with no charset and no Cache-Control, and a UTF-16 page decoded it as UTF-16 - no completion hook, TIMEOUT - until the alias directory carried the stock file's `.headers`.

**Why**: HTML's "fetch a classic script" falls back to the document's encoding when the response names no charset; wptserve sends an aliased file's `<file>.headers` (handlers.load_headers) and nothing else. The stock resources/testharnessreport.js.headers says `Content-Type: text/javascript; charset=utf-8` and `Cache-Control: max-age=3600`, and wptrunner serves its own report "text/javascript;charset=utf8". An alias's "local-dir" is also the DIRECTORY holding the file: wptserve joins it with the URL's last segment.

**What Happened**: The production validation run had html/syntax/charset/without-inheritance.html (UTF-16LE) and the-input-byte-stream-003/004 time out. With the headers added they were back to generation 213's counts - and fetching the harness as a browser does also put testharness.js on every page's resource timeline, from Crane's HTTP cache after the first page, which exposed a real Resource Timing bug (a cache hit's domainLookupStart and requestStart read 0; resource-timing-level1.sub.html, fixed in src/fetch).

**Fix**: tests/wpt_runner/resources/testharnessreport.js.headers, a copy of the stock one; the runner refuses a server that serves the report without charset=utf-8; the pool hosts' config.json aliases the runner's resources directory.

**Takeaway**: **A script you serve in a test page's place must carry the stock file's headers - its charset above all - or every page in another encoding decodes it wrongly; and once the harness travels the browsers' path, expect it to show you bugs the old shortcut hid.**
