# Debugging: A stream factory that fails after its controller exists leaves the source with two owners

**Date**: 2026-10-29
**Lesson**: Once a controller holds the underlying source, a failed setup must clear the controller's algorithms itself. If it does not, the caller frees the source on failure, the controller frees it again at its collection, and every late setup failure becomes a double free.

**Why**: `createReadableStream` has had a failure contract since e0adeb08ebb (2026-10-11): `source` is the call's, failure included. `createReadableByteStream` (src/webidl/impls/streams_readable.zig) never got that contract. Its two native callers were written as if it had:

- fetch_body's `PipeStream.create` (Response.body, text(), ...) and Blob's `BlobStream.create` (Blob.stream()) each take a busy hold for the call.
- Their comment says "a failed setup clears the source's algorithms, which must not free it under this call".
- On failure each marks itself detached and frees itself.

Suppose `SetUpReadableByteStreamController` fails at its last step: the start promise's reaction, which is refused while the realm's end is under way. The controller is wrapped by then, and it still holds the source in `c.source`. The caller frees the source. When the realm ends or the wrapper is collected, `ByteController.deinit -> byteClearAlgorithms -> the source's deinit` writes `detached` and `controller` into the freed block and frees it a second time. It is a use-after-free write as well as a double free.

**What Happened**:
- Lane leaks1's Debug runs over row 125's Q97 shard saw it 3 times in 24, in FileAPI/BlobURL/cross-partition.https.html.
- Generation 194's sweep logged it once ("Double free detected", empty traces in ReleaseSafe), in html/cross-origin-embedder-policy/credentialless/dedicated-worker.https.window.js next to link.https.window.js.
- Agent gen194 reproduced it in-process: (dedicated-worker, link) x 40 gave 1-4 reports per run on every frozen main back to 2026-10-25. A Debug runner traced it (tmp/analysis/gen194-dfree.md): first free at PipeStream.create's error branch, second at ByteController.deinit.
- The refused reaction came from a worker's or popup's realm ending on another thread, a race no single test file times. So the defect lived from 2026-09-22 to 2026-10-29 and surfaced about once per sweep.

**Fix** (lane leaks1, 509cfd80b3b):
1. `createReadableByteStream` takes `createReadableStream`'s contract.
   - Until the controller holds the source, an errdefer runs the source's deinit.
   - From then on, an errdefer clears the controller's algorithms (`byteClearAlgorithms`) before the error returns. A wrapped controller then outlives the failure holding nothing, and an unwrapped one is released.
   - Either way the source's deinit runs exactly once under the call. The caller's busy hold defers the real free to its own error branch.
2. Pin it with a failing-step trial per source kind. tests/v8/bytestream_setup_failure_test.zig refuses the start reaction for one call by marking the realm's reaction list ended, the check `reactToPromise` makes first. The realm and its wrappers stay live, so the controller is wrapped, as in the WPT runs. The test does this for Blob.stream() and Response.body; then the realm ends normally. tests/v8/microtask_dropped_end_test.zig covers the realm-end variant, where nothing is wrapped and the old code leaked instead.

**Takeaway**: **Once a controller holds the underlying source, a failed setup must clear the controller's algorithms itself; a caller that frees the source on failure turns every late setup failure (a refused promise reaction in a terminating realm) into a double free at the controller's collection. Give every create*Stream the same "source is the call's, failure included" contract, and pin it with a failing-step trial per source kind.**
