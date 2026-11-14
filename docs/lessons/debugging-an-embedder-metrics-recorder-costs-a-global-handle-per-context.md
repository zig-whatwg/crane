# Debugging: An embedder metrics recorder makes V8 keep a global handle per context

**Date**: 2026-11-10
**Lesson**: Installing a `v8::metrics::Recorder` (Isolate::SetMetricsRecorder) changes what the isolate holds: for every context a full collection is reported for, V8 keeps a weak `Global<Context>` to name it, so a diagnostic recorder in Crane's own build shows up in every global-handle count.

**Why**: With an embedder recorder set, GCTracer::ReportFullCycleToRecorder passes `GetContextId(isolate)`, which calls `Isolate::GetOrRegisterRecorderContextId(native_context)`; the first time a context is seen V8 puts a weak Global for it in `recorder_context_id_map_` (V8 13.1.203 src/execution/isolate.cc), cleared only when the context dies. Without a recorder V8 skips the whole report.

**What Happened**: Lane wr1 batch 8 installed a recorder on every agent's isolate to split the full-collection pause into V8's own phases (mark, weak, compact, sweep) and the C++ heap's. tests/v8/worker_iterator_template_test.zig failed: "global handles 0 -> 96 bytes (32 a handle) over 4 realms" - one recorder handle per worker realm a collection had reported.

**Fix**:
1. The recorder exists only in gc_bench's build (v8_wrapper.cpp `CRANE_GC_PHASE_METRICS`, on with `-DCRANE_TRACK_GLOBALS=1`, which only gc_bench passes); its counters read 0 elsewhere.
2. Diagnostics that cost nothing (two clock reads per collection, the anchors' weak-processing timer) stay in every build.

**Takeaway**: **A V8 diagnostic hook is not free of state: read what V8 does when the hook is present before installing it in the production build, and keep the ones that hold anything to the measuring build.**
