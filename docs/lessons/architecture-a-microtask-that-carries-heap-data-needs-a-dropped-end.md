# Architecture: A microtask that carries heap data needs a dropped end

**Date**: 2026-10-29
**Lesson**: `engine.queueMicrotask` has no dropped end. A microtask that never runs (the agent's queue thrown away by a terminated checkpoint, or the agent ending) never tells the host. So any heap data handed to it leaks. Heap-carrying microtasks go through `engine.queueRealmMicrotask`, and the streams helper `js.queueMicrotask` now requires a `dropped` step.

**Why**: The protocol says it in so many words (engine_protocol.zig, `queueMicrotask`): "There is no dropped end ... `data` that must be freed goes through `queueRealmMicrotask` instead." The streams helper `js.queueMicrotask` wrapped the operation with no drop. Fetch's read loop and the three tee chunk steps used it, and so did `queueMicrotask()` and the mutation observer microtask. Each handed over a struct it allocated and freed only in the steps. This is the microtask form of [A callback the engine may never make needs a dropped end](architecture-a-callback-the-engine-may-never-make-needs-a-dropped-end.md), which fixed promise reactions in October and left `queueMicrotask` as it was.

**What Happened**: Three times, rows 124/125 saw exactly three `error(DebugAllocator): ... leaked:` reports with empty stacks at the end of one WPT runner process. Each process ran the FileAPI/accname/console/CSP head of the worklist, and 36+ ReleaseSafe reruns reproduced none. The reports printed after the shard's last file, a CSP test, so the CSP files were suspected.
- A Debug runner with `CRANE_LEAK_TRACES=1 CRANE_LEAK_FILES=1` ran in a single process over the exact 66-file shard, 4 loops x 6 times (lane leaks1). It reproduced the leak 4 times in 24 and named it: "3 allocations, 366 B, allocated while running FileAPI/BlobURL/cross-partition.https.html". That file is the shard's FIRST.
  - The three blocks were fetch_body's `FullRead`, its `Deferred`, and its bytes.
  - That page's dispatcher executors poll with `fetch().text()` in workers and iframes, and the test's end terminates them. A chunk arrives, `FullRead.chunk` queues the next read as a microtask, the worker is terminated mid-checkpoint, and V8 deletes the rest of the queue.
- The same 24 runs showed a double free 3 times (a related ownership gap). `CreateReadableByteStream` had no failure path. A setup that failed after its controller was wrapped left the controller holding the source that `PipeStream.create` then freed.
- The empty stacks were never a clue. The runner's fast allocator records no traces (`stack_trace_frames = 0`).

**Fix**:
1. `js.queueMicrotask(realm, Ctx, ctx, callback, dropped)` queues through `engine.queueRealmMicrotask`, and `dropped` is a required parameter. The callers pass their free functions: `FullRead.destroy`, `TeeChunk.dropped`, `ByteTeeChunk.dropped`.
2. `queueMicrotask()` (WindowOrWorkerGlobalScope) became a realm microtask whose drop releases the callback.
3. The mutation observer microtask stays an AGENT microtask. It notifies every pending observer of the agent, whichever realm queued it. So it carries no data: the steps read the agent's state instead.
4. `createReadableByteStream` took `createReadableStream`'s failure discipline. On failure the source's deinit runs once, and a wrapped controller's algorithms are cleared before return.
5. tests/v8/microtask_dropped_end_test.zig ends the checkpoint with `engine.abortRunningScript` from a builtin, so the queue is thrown away. Or it ends the realm with the microtask queued. Every agent and realm in it is on `std.testing.allocator`.

**Takeaway**: **Data handed to a microtask is freed only by a microtask that runs, unless the queue can tell you it dropped it: use `queueRealmMicrotask` (or carry nothing). And a leak report printed when a process ends names the process, not the file. Attribute it with `CRANE_LEAK_FILES` before suspecting the files that ran last.**
