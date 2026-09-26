# Testing: The report was written after teardown, so a teardown crash erased the run

**Date**: 2026-09-22
**Lesson**: `run()` wrote `wptreport.json` after `executeTests` returned, and
`executeTests` ends with a deferred `browser.deinit()`. Every result a run
produced therefore lived only in memory while the browser tore down.

**What Happened**: `custom-elements/connected-callbacks.html` ran all of its
tests, then died in `Browser.deinit -> cleanupAllDomRegistries ->
Element registry sweep -> NamedNodeMap.deinit -> stateAs` reading an Instance
the wrapper cache had already freed. The process exited 134 and there was no
report at all - "NO REPORT", which reads as "the test never ran", the opposite
of what happened. Before the allocator fix above it took 21 seconds to get
there, so it read as a hang.

The sharded path is different: `runShard` journals per file and declines to
blame a file when the child dies after the last one is journalled, so a sweep
loses nothing to a teardown crash. It was the standalone path - the one used
to reproduce and fix things - that lost everything.

**Fix**: `executeTests` finishes and writes the report before returning, inside
the frame whose defer tears the browser down. `run()`'s later write overwrites
it with identical results.

**Takeaway**: **Persist results before teardown; teardown is engine code and
crashes like any other.** "NO REPORT" now means the run never produced one,
not that the exit destroyed it - and a crash in teardown still exits non-zero,
so it is not hidden either, only no longer paid for with the data.
