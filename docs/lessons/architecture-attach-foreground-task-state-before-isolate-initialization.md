# Architecture: Attach foreground task state before isolate initialization

**Date**: 2026-10-21
**Lesson**: A host task-runner adapter must be available during V8 isolate initialization because V8 retains runners acquired then.

**Why**: V8 13.1.99 caches a runner in `src/heap/heap.cc` during setup, and the incremental-marking job and memory reducer keep runners of their own. Wrapping only later GetForegroundTaskRunner calls misses posts through those retained runners. Atomics.waitAsync obtains its runner later, so its timeout test alone cannot expose this gap.

**What Happened**: The first foreground wake/deadline design would have delegated initialization-time requests directly to DefaultPlatform, permanently bypassing the host wake path for heap maintenance tasks.

**Fix**: Use the public Isolate::Allocate, SetData and Isolate::Initialize sequence with the same CreateParams as New. Put the existing per-isolate task state in its owned embedder record before Initialize, and attach the retained host TaskSink afterward. Cached runners share that state. Close it before isolate shutdown; late foreign-thread posts discard their tasks without touching the former sink. Test a runner captured before sink attachment on both fresh and snapshot isolate paths.

**Takeaway**: **A cached dependency is configured at first acquisition, which can occur inside the constructor.**
