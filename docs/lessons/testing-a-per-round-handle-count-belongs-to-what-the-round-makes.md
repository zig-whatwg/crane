# Testing: A per-round handle count belongs to what the round makes, until a bare round says otherwise

**Date**: 2026-11-03
**Lesson**: Six global handles a round under a stream script read as "every classic script evaluation keeps 6". A bare evaluation keeps none: they were the streams' own, held for the realm's life by design. Before blaming the path every round shares, measure that path alone, then each kind of object the script makes, and name what the handles hold.

**Why**: A control round subtracts what the control and the subject share - and so hides it. Lane tsanfix1 measured `values()` against a control stream and got 4 a call; without the control it read 6 a round under every stream script, and filed the 6 as a per-evaluation retention in the adapter's script path. Both rounds made a ReadableStream, and a streams-graph object's wrapper is held strongly until its realm ends (`wrapper_cache.isStreamsGraphObject`, runtime/streams_graph.zig). What both rounds shared was the stream, not the evaluation.

**What Happened**: Lane leakcheck1 measured each script alone with the agent's own `v8_Isolate_GetGlobalHandleBytes`, the adapter's counters (`engine.diagnosticCounters`: wrapper_cache_entries, live_object_globals, live_weak_callback_data) and a heap snapshot's "(Global handles)" root diffed across the rounds (`engine.writeHeapSnapshot`). Per round, at 100 and 1,000 rounds alike:
- `'ok'`, `({})`, a promise reaction, an async function, a sync iterator: 0.
- `new ReadableStream()`: 2 (the stream's and its controller's wrappers).
- `getReader()` and `values()`: 6 - the reader's wrapper and three Promise handles, its [[closedPromise]] (the capability's resolver and promise, and the Deferred's own hold). The iterator itself is collected, its weak record with it.
- An undrained stream (`enqueue` then `close`): 4 - its underlying source object and `start` closure stay until the queue drains.
- Linear to 1,000 rounds, and the realm's end returned all 6,018 handles a second realm's 1,000 `values()` rounds kept.

**Fix**: Nothing in the script path. tests/v8/async_iterable_release_test.zig pins a bare evaluation at 0, the iterator's own handles at 0 per call beyond its stream's DECLARED realm hold, and the realm's end at 0 (the bound). What the measure named was cut where it was waste: a settled streams promise (streams_js.Deferred) released its capability only with the Deferred, so every settled promise a stream keeps held its resolver and the capability's promise for nothing - now one handle, not three (tests/v8/streams_settled_promise_handles_test.zig; values() 6 -> 4 a call). The rest is the streams graph's realm hold, whose owner is the streams lifetime design (refcount design D3, phase 2), not a dropped Global.

**Takeaway**: **Measure the shared path alone before naming it: a per-round handle count under a script belongs to the objects that script makes until a bare round reads 0 or not - and a heap snapshot's "(Global handles)" diff names what they are.**
