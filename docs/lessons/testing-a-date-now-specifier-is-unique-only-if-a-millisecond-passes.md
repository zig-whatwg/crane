# Testing: A Date.now() specifier is unique only if a millisecond passes

**Date**: 2026-10-31
**Lesson**: A test that makes a URL "new" with `"x.js?" + Date.now()` assumes the previous test took at least a millisecond. When Crane finishes that test in under one, the "new" URL is the previous test's, already in the module map, and the spec's cached path runs.

**Why**: html/semantics/scripting-1/the-script-element/module/dynamic-import/microtasks/basic.any.js test 2 imports `empty-module.js?<Date.now()>` (a fetch) and imports it again (cached). Test 3 does the same with a fresh `Date.now()` and expects `import()` to wait for a task, so a 1,000,000-tick microtask ticker has drained. A browser's module fetch takes milliseconds. Crane's, from the local wpt serve, plus the cached re-import, often takes less.

**What Happened**: "import() should drain the microtask queue when fetching a new module ... expected 1000000 but got 3" was a sweep-only flake in five generations. It passed 0/60 isolated, 0/90 under load and 0/40 replaying the sweep shard. `wpt_runner --repeat=200 --load=4` (flaky1's mode) on a loaded chat.local reproduced it: window variant 4/200, sharedworker 1/200, the same on base and tip. A probe ran tests 2-3 sixty times per page and logged both Date.now() values whenever test 3's import settled before the ticker drained. All 928 such cases had d2 == d3, and none had different values. 3 ticks is exactly ContinueDynamicImport's reaction chain for a cached module.

**Fix**: None in Crane: the cached path is the spec's (whatwg/html#8264), and slowing fetches down to dodge a test's assumption is not a fix. The upstream test would need a unique specifier (a counter, `crypto.randomUUID()`); filing that needs the user's OK.

**Takeaway**: **Before chasing a "drained too little" ordering flake, log the inputs the test assumed were fresh (Date.now(), random seeds): a fast engine can make two tests share one.**
