# Testing: A handle-leak test needs V8's live count, not the debug counter

**Date**: 2026-09-26
**Lesson**: Assert "no handle leaked" with `v8_Isolate_GetGlobalHandleBytes`, V8's own live count; `v8_Debug_CreatedGlobals` is compiled out of every build but gc_bench and counts creations, not live handles.

**Why**: The wrapper has two families of handle counters. The `v8_Debug_*`
counters exist for gc_bench: `trackHandle` bumps them only under
`-DCRANE_TRACK_GLOBALS=1`, which build.zig passes to gc_bench alone, and
`CreatedGlobals` never goes down - it is a creation rate, read across a loop. In
a test binary it is a constant 0. V8's `HeapStatistics::used_global_handles_size`
is `GlobalHandles::UsedSize()`, the regular node count times the node size,
adjusted the moment a `Global` is created or reset, in every build.

**What Happened**: `v8CreateUint8Array` never disposed the `Global<ArrayBuffer>`
it made for the view's backing store, one leaked handle per call (TextEncoder,
`Response.bytes()`). The first test for the fix read `v8_Debug_CreatedGlobals`
before and after. Its red run failed - "expected 1, found 0" - and that looked
like the leak, until the numbers were read: a leak gives before+2 then before+1;
0 means the counter never moved. The test would have failed with the fix in
place too, and the gate was stopped before it said so.

**Fix**: `v8_Isolate_GetGlobalHandleBytes(isolate)` (ffi.zig, v8_wrapper.cpp)
returns `used_global_handles_size`. The test runs the operation 32 times,
disposing each result, and asserts the count is no higher than before - robust
to node size and to a GC reclaiming some unrelated weak handle, and 32 leaked
nodes can hide in nothing. `CreatedGlobals`' doc comment now says it is 0
outside gc_bench.

**Takeaway**: **Read a red run's numbers before believing it: a failing assertion is red for a reason, and the reason has to be the bug.**
