# Testing: ThreadSanitizer does not see the order libdispatch keeps - a dispatch handler's hand-overs need their own acquire/release

**Date**: 2026-11-17
**Lesson**: State written by one thread before `dispatch_resume` and read by a dispatch source's handler on a queue's thread is reported as a data race by Zig's ThreadSanitizer, because its libtsan has no libdispatch interceptors: put an acquire/release pair of the file's own on every hand-over, and run the darwin-bound tests under `-Dsanitize-thread` on macOS before calling a darwin change green.

**Why**: libdispatch guarantees the order - a source's handler runs only after the resume, its cancel handler only after `dispatch_source_cancel` and after any running event handler, and a thread that waits on a semaphore the cancel handler signals continues only after it. Clang's TSan on Apple platforms knows this through libdispatch interceptors; the libtsan Zig 0.17 ships has none, so it sees a write on the main thread, a read on a GCD worker, and nothing between. The Linux half of the same feature (a thread woken by a futex and joined) is ordered by pthread calls the sanitizer does intercept, so the Linux TSan run was green and said nothing about darwin.

**What Happened**: Lane mp1's darwin memory-pressure observer (one DISPATCH_SOURCE_TYPE_MEMORYPRESSURE source per Browser) passed every plain gate on both OSes, and `test-verify -Dsanitize-thread` on the changed test files on both - those files are bound to the testing platform, which has no observer. The platform test step under `-Dsanitize-thread` on macOS, which runs the per-adapter conformance executables, failed 8 tests: every darwin-bound test that makes a Browser's platform state crashed on the report (Observer.start's write against handleCancel's read). The integrator had asked for that run on Linux for the poller; it was run on macOS only because the lane's gate script ran the same steps on both hosts.

**Fix**:
1. One atomic word on the object (`order`), and a `handOver()` that does `fetchAdd(1, .acq_rel)`: the publishing thread calls it after its last write and before `dispatch_resume`; each handler calls it on entry and on exit; the stopping thread calls it after the cancel handler's signal, before it touches the object again.
2. Say in the file that the pairs are correct on their own (the memory model's ordering, not relying on libdispatch's inside) - this is not a suppression, and nothing goes in tsan_suppressions.txt.
3. A change to a darwin or linux adapter runs `zig build test -Dspec=platform -Dsanitize-thread` on ITS OWN OS: the per-adapter conformance executables are the only tests that run the adapter's threads.

**Takeaway**: **A sanitizer only knows the synchronization it intercepts: order kept inside libdispatch is invisible to Zig's TSan, so give a dispatch handler's hand-overs an acquire/release of your own, and run each adapter's conformance tests under TSan on its own OS.**
