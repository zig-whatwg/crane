# Debugging: A cleanup walk run on every call is quadratic once a new caller makes it hot - time the harness's own per-test path

**Date**: 2026-10-03
**Lesson**: Moving AbortSignal.reason onto traced values made 8,000 testharness `test()` calls take 1.5 s instead of 0.3 s: `WrapperCache.deferEdge` pruned dead owners by walking its whole map on every call, and every Test's AbortController keeps a signal script never wraps and aborts it at cleanup - one more entry, one more full walk, each time.

**Why**: The prune was correct and cheap while its only caller was rare (traceChild from a Zig-made event before dispatch). A new caller on a per-test path turned O(n) per call into O(n^2) per page. Nothing failed: the A/B showed two 7,773-subtest wasm files going OK -> TIMEOUT, which looked like machine load - both baseline and tip timed out when re-run alone under the same load.

**What Happened**: Interleaved single-file runs (base, tip, base, tip) showed the tip consistently ~7% behind by the timeout - not load. A page timing 8,000 trivial `test()` calls (328 ms vs 1,533 ms) localized it to the harness; a page timing single operations (`new AbortController()`, `abort()`, with and without reading `.signal`) found it in `abort()` on a never-wrapped signal, growing with the number of controllers alive.

**Fix**: prune a map of fewer than 64 owners every call, larger ones only once the map has doubled since the last prune (amortized O(1)). After: 367 ms (main 340), the wasm file level with main.

**Takeaway**: **When an A/B times out a few heavy files, run base and tip interleaved under the same load before calling it noise - and time the harness's per-test path (test(), its AbortController, its result callbacks): every WPT file pays it thousands of times.**
