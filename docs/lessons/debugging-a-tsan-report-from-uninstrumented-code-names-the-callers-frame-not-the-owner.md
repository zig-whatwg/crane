# Debugging: A ThreadSanitizer report from uninstrumented code names the caller's frame, not the owner

**Date**: 2026-11-09
**Lesson**: In code TSAN did not instrument (the V8 prebuilt), a report's stack has two frames: the intercepted call (`pthread_mutex_destroy`) and its immediate caller. That caller is whichever destructor the inlined `~Mutex` sits in. So one ownership mechanism shows up under as many names as there are owners, and the frame that orders the accesses never appears.

**Why**: TSAN builds its stacks from the function entry and exit hooks that instrumentation inserts. Uninstrumented code has none, so only the interceptor's return address is known. The ordering edge was a `shared_ptr` count decrement (acq_rel) inlined in V8. TSAN cannot see it, so the destructor that follows looks like a race with the last lock taken by the other thread.

**What Happened**: lane wr1 b2's ThreadSanitizer verify of tests/v8/page_realm_operations_test.zig failed twice on server1, Linux x86-64. Each failure was a `pthread_cond_destroy` or `pthread_mutex_destroy` in `v8::platform::DefaultJobState::~DefaultJobState` on a V8 worker, against the main thread's `pthread_cond_wait` in `DefaultJobState::Join`.
- The verdict block showed only the reports' tails: the threads' creation stacks and the SUMMARY line. The launcher rerun with `--batch=0 --out=` gave the whole reports.
- The mechanism (default-job.h:85, 130-156): a worker locks a `weak_ptr<DefaultJobState>`. The joining thread drops its handle's strong reference. When the worker's local `shared_ptr` is the last one, `~DefaultJobState` runs on the worker, and so does its `job_task_` (a `unique_ptr<JobTask>`).
- With that entry in place, the same mechanism came back as `ParallelClearingJob::~ParallelClearingJob`, then `PointersUpdatingJob::~PointersUpdatingJob`, then `PageEvacuationJob::~PageEvacuationJob`: each JobTask whose members hold a mutex.
- A family pattern (`race:v8::internal::*Job*::~`) was turned down. A `race:` entry matches a frame in EITHER stack, so it would also hide Crane ending an isolate, or freeing its CppHeap, while a V8 job still runs: the report whose other stack is a job's destructor.

**Fix**: tools/test_launcher/tsan_suppressions.txt holds one entry per proven class, each with its report. The mechanism is written once, at the DefaultJobState entry. The proof run is `--batch=0` over the file's tests across seeds, with `TSAN_OPTIONS=print_suppressions=1:log_path=<dir>/s<seed>`. TSAN writes a log only for a process that printed something, so each file holds that process's "Matched N suppressions", or the report that still fails.

**Takeaway**: **Before suppressing a TSAN report from uninstrumented code, find the owner whose destructor runs on the racing thread. Expect it under every owner's name, and add an entry for each class only once that class's own report shows the other stack is the engine's alone.**
