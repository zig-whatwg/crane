# Architecture: An owned field added to a result that callers take apart leaks in every one of them

**Date**: 2026-10-04
**Lesson**: FetchResult gained `referrer: ?[]u8` (owned, freed by FetchResult.deinit) for one caller, the frame navigation. Six other callers never call FetchResult.deinit - they free `response` and `timing_info` themselves - so every external script, module, worker script and synchronous XHR fetched with a URL referrer leaked the copy.

**Why**: A result struct whose callers move its parts out (the response handed on, the timing info kept) is not freed through its deinit, and adding an owned field silently adds a leak to each of those call sites. Nothing fails to compile; std.testing.allocator sees it only in tests that fetch with a referrer, and the runner's DebugAllocator prints it per file.

**What Happened**: navigation batch 6's probes went from 1 DebugAllocator `leaked:` line (t1) to 3,054 (t2) when the referrer landed; statuses did not move, so the A/B would have missed it. Auditing `algorithms.fetch(` and `takeResult()` callers found the piecemeal frees (script_execution, module_script, worker_host, workers/script_fetch, xhr fetch_integration, browser/navigation).

**Fix**: 00a7de29f1 - `FetchOptions.report_referrer` (default false): the job dupes the referrer only for the caller that asks, and that caller frees the result with FetchResult.deinit. Leak lines 3,054 -> 0.

**Takeaway**: **Before adding an owned field to a result type, grep how every caller frees it; if any takes it apart, make the field opt-in or borrowed - and count `leaked:` lines in the probe log, not only statuses.**
