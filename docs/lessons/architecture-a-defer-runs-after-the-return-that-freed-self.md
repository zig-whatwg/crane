# Architecture: A `defer` runs after the `return self.end()` that freed `self`

**Date**: 2026-11-04
**Lesson**: In `defer self.allocator.free(bytes); ... return self.finish(false);`, `finish` runs first - and frees `self` - and the defer runs after it, reading the freed object's allocator. The same holds for a step that calls script: the script's microtask checkpoint can run the reaction that ends the object before the step's next line.

**Why**: Zig evaluates a `return` expression, then runs the scope's defers. A function whose last call frees its receiver (`finish`, `end`, `destroy`) must be the last thing that touches the receiver - and a defer written above it is not "above" it at run time. And a call into script is a callback: when the JavaScript execution context stack is empty, HTML's "clean up after running a callback" runs a microtask checkpoint as it returns (V8's kAuto policy at call depth 0), so whatever reaction the call settled runs before the next line - including one whose end frees the object the step is in.

**What Happened**: Lane crashes8, the two service-worker crashes chromeref2's release runner found (both passed under the DebugAllocator, which never poisons or reuses a freed slot):
- `InternalBodyPump.notify` (fetch_event.zig) took the body's new bytes with `defer self.allocator.free(bytes)`, wrote them to the relay, and on a failed write - the page's reader had gone - did `return self.finish(false)`. `finish` destroyed the pump; the defer then read `self.allocator` from it (fetch-canvas-tainting-video.https.html, a fault at 0xfc in rawFree).
- `BodyPump.cancelForReader` called the reader's `cancel()`. The stream's cancel algorithm is a script callback; the checkpoint after it ran the pending read's reaction ({done: true}), whose close step finished and freed the pump; the cancel then read `self.realm` for `markPromiseAsHandled` (fetch-event-respond-with-readable-stream.https.html, a fault at a free-list address in realm_entry.enter).
Beside them, `PipeSource.notifyAll` (body_pipe.zig) went on reading the source after a reader released the source's LAST branch inside its notification - which freed the source - and `finish`/`fail` freed it a second time.

**Fix**:
1. Make the freeing call the last step of every path: free the bytes, then `if (!written) return self.finish(false)` (InternalBodyPump, and cache/api.zig's InternalBodyRead, which had the same shape).
2. Where a step must use the object after calling script, hold it: `cancel_hold` set before the cancel; a `finish` under it marks `finished` and returns, and the hold's end frees the pump (docs/lessons/architecture-a-callback-can-end-its-own-environment.md).
3. A source holds itself while it delivers: `delivering` counts `push`/`finish`/`fail` in progress, `freeIfUnused` waits for it to reach zero, and each delivery frees the source as it returns if nothing else holds it.
4. Red tests on an allocator that unmaps on free: tests/fetch/c8_body_pipe_reentry_test.zig, tests/service_worker/c8_body_pump_end_test.zig.

**Takeaway**: **Before a call that can free `self` - an end, a release, or any call into script - read the function's defers and everything after the call: none of it may touch `self`. Free what you hold first and make the end the last step, or hold `self` across the call and let the hold's end free it.**
