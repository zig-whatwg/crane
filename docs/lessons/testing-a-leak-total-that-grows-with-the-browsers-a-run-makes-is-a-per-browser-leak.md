# Testing: A leak total that grows with the Browsers a run makes is a per-Browser leak

**Date**: 2026-10-17
**Lesson**: Compare `leaks --atExit` runs by stack, and count the Browsers each run made, before blaming a change for a bigger total.

**Why**: A `leaks --atExit` run of the WPT runner is one process that makes a Browser, and a new one after every file that
needs a fresh start. A leak that happens once per Browser - or once per isolate - scales with that count, not with the
code under test. Change how often the runner restarts and the total moves, though no path the change touched leaks.

**What Happened**: Lane sw1-b3 made the runner restart its Browser after any file that leaves a service worker
registration (b9a2e97e926), and every `.any.serviceworker.html` variant leaves one. Its leaks run over fetch/api/
went from 55 leaks (21 MB) on the base to 249 (265 MB) on the tip; over service-workers/, 94 (106 MB) to 159
(165 MB). Grouped by stack, the difference was one entry: `ROOT LEAK: <malloc in v8_Isolate_NewFromSnapshot>` from
`BrowserAdapter.init -> protocol.createAgent`, 5 -> 98 instances in fetch/api/ and 39 -> 60 in service-workers/ - one
per Browser. v8_Isolate_NewFromSnapshot copies the 2.6 MB snapshot blob for each isolate and keeps the copy and its
StartupData "for the life of the process" (v8_wrapper.cpp); nothing frees them when the isolate is disposed. The only
other movement was a known per-call leak (V8Interface(Headers).returnNewIterator) reached more often now that fetch
events run. Nothing in the lane's own paths leaked.

**Fix**:
1. Group each run's report by stack: the "STACK OF N INSTANCES OF 'ROOT LEAK: <...>'" blocks, keyed by the innermost
   frames above the allocator; compare the counts, not the totals.
2. For a stack whose count moved, ask what it is per: per call, per Browser, per isolate, per file. Count how many of
   those each run made (here: one `BrowserAdapter.init` per Browser).
3. A per-Browser leak is real - an embedder that makes Browsers over time pays it each time - but it belongs to its
   owner (here the V8 adapter), not to the change that made the runner start more Browsers. Name it to that owner.

**Takeaway**: **A leak total is a sum of per-something leaks; find the something before reading the total as the
change's - group by stack, and divide by the Browsers, isolates or calls each run made.**
