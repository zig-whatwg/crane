# Measurement: V8 first-use queues affect persistent-handle probes

**Date**: 2026-10-21
**Lesson**: Isolate an unexplained persistent-handle increase with a direct engine control before attributing it to a callback adapter or dismissing it as warmup.

**Why**: V8 itself can create persistent handles when its tiering machinery first activates. A handle-byte counter sees those allocations alongside embedder handles.

**What Happened**: A callback-return probe stayed at 288 bytes for seven calls, rose to 320 on call eight, and stayed there through 128 calls and forced GC. Linked V8 13.1 sets invocation_count_for_feedback_allocation to eight. Its first Sparkplug enqueue creates one persistent weak compilation queue. An unrelated function called directly through V8 reproduced a separate 320-to-352 increase without invoking Crane's callback adapter.

**Fix**: Initialize the compilation queue through the unrelated direct-V8 control, then compare two 64-call adapter batches. Both stayed at 352 bytes. The ownership assertions remain exact. Source evidence: V8 13.1.99 `src/flags/flag-definitions.h:853`, `src/execution/tiering-manager.cc:530`, and `src/baseline/baseline-batch-compiler.cc:296`.

**Takeaway**: **A one-time increase is a hypothesis to explain, not permission to loosen a leak assertion. Use an independent control and identify the allocation.**
