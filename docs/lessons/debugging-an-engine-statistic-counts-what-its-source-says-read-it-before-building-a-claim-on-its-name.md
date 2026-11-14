# Debugging: An engine statistic counts what its source says - read it before building a claim on its name

**Date**: 2026-11-12
**Lesson**: Before a number from an engine's statistics API carries a conclusion, read the line of the engine that fills the field. `v8::HeapStatistics::external_memory()` is not the embedder's reported external memory.

**Why**: In V8 15.7 `Isolate::GetHeapStatistics` sets `external_memory_` from `heap->backing_store_bytes()` - ArrayBuffer backing stores only (src/api/api.cc:10585-10587). The external memory an embedder reports through `ExternalMemoryAccounter` (Crane's DOM figure) is counted toward V8's global allocation limit (`Heap::external_memory()`), and `HeapStatistics` does not show it at all. The two share a name and nothing else.

**What Happened**: Lane v8up b7's page-load experiment compared a threshold with `used_heap_size() + external_memory()` and logged it per navigation: about 1.3 MB more per page left, where the footprint grew about 8 MB. From that I told the integrator "V8 sees a sixth of what a dead page holds" and proposed a queue entry against the DOM's external-memory accounting. V8's own trace of the same page, already in the lane's notes, said otherwise: `[IncrementalMarking] Start (task): v8: 25MB / limit 32MB, global: 56MB / limit 64MB` at the eighth page - V8 counted 56 MB of a 100 MB footprint, about half, which is ordinary. The claim was withdrawn ten minutes later, before anything was queued; the measured behaviour was right, its description was not, and the option's documentation now says exactly what the threshold measures (objects in V8's heap plus ArrayBuffer backing stores).

**Fix**: (1) For any figure read through an engine API, open the function that fills it and write down what it sums, with file and line, next to the first use. (2) Check a surprising ratio against the engine's own trace of the same run (`--trace-gc`, `--trace-incremental-marking` print the sizes the collector decides on) before reporting it. (3) Name a threshold by what it measures in the option's doc and tests, not by the API field's name.

**Takeaway**: **A statistics field is defined by the code that fills it. Read that code, and cross-check with the collector's own trace, before a number from it becomes a finding - above all when the number is surprising.**
