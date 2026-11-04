# Testing: A release-runner run with a memory sampler finds what the correctness sweep hides

**Date**: 2026-11-04
**Lesson**: The first full worklist run of the release runner (libc malloc, every 1 s a phys_footprint sample per runner) found two use-after-frees and a 61 GB runaway. Every correctness sweep before it had passed all three files.

**Why**: The correctness runner allocates through Zig's DebugAllocator, which does not hand a freed slot straight back to the next allocation. A read through a dangling pointer then finds the old object intact, and the test passes. libc malloc reuses the slot at once, so the same read finds another object's bytes and faults. Separately, no sweep records memory: a journal line has the V8 heap (`heap_used_kb`), never the process's native footprint. A file whose runner grows to 61 GB of native memory still journals TIMEOUT with 4 passing, as it always has.

**What Happened**: Lane chromeref2's final Crane-vs-Chrome window ran the release runner over 13,197 files. 13,195 files matched the latest correctness sweep's status and passing count exactly. The two that did not crashed with SIGSEGV on the service worker's event-loop thread, in every rerun, on both V8 builds:
- fetch-canvas-tainting-video.https.html: `body_pipe.notifyAll` calls a freed consumer;
- fetch-event-respond-with-readable-stream.https.html: `realm_entry.enter` reads a freed realm, from a queued markPromiseAsHandled task.

The correctness runner passes both. The memory sampler's engine peak was 62,353 MB against a mean of 648 MB without that minute and a half. Chunk abd's five shards, rerun as in the sweep, put it in shard 1. The shard's files alone named html/cross-origin-embedder-policy/worker-inheritance.sub.https.html: 61.5 GB on the release runner and 62.5 GB on the correctness runner. The runaway is on main, and was simply never measured.

**Fix**:
1. Run the release runner over the worklist and diff it against the latest correctness sweep. Rerun every differing file alone on BOTH runners, and on a second V8 build when one exists. A difference that each runner repeats is a build-mode bug, not noise, and a crash only libc malloc shows is a use-after-free.
2. Sample each runner process's phys_footprint every second, and keep the per-second CSV. To name the file behind a peak:
   - find the chunk by the sample's time;
   - rerun the chunk's shard lists, each as its own runner, all at once as in the sweep;
   - lay the peak shard's journal walls end to end, and run the candidate files alone under `/usr/bin/time -l`.
3. The scripts and logs are in chat.local ~/crane-work/chromeref1-bins/ (probe.sh, probe2.sh, probe3.sh; window3/diff, probe-abd, probe3).

**Takeaway**: **The DebugAllocator hides use-after-frees and the journal hides native memory: a libc-malloc run with a per-runner memory sampler is a detector the correctness sweep is not. Diff it against the sweep, and rerun each difference alone on both runners.**
