# Spec Compliance: A deferred pipe write is part of shutdown

**Date**: 2026-10-18
**Lesson**: Moving a stream write onto a microtask also makes its pending chunk part of the pipe's shutdown state.

**Why**: ReadableStreamPipeTo step 15 requires asynchronous activity. Both shutdown algorithms, step 3, require already-read chunks to be written before their action runs while the destination remains writable. A promise for the previous write does not describe a chunk whose write has not started yet.

**What Happened**: Crane's pipe read callback invoked the sink's write synchronously from `controller.enqueue()`, failing `streams/piping/general-addition.any.js` in every variant. Moving only that invocation later would let a source close overtake its final chunk.

**Fix**: Keep the chunk through the existing owned-value mechanism and queue a realm-owned microtask. Track the queued interval. If shutdown reaches this interval, resume its wait after the write's promise exists. Release the chunk on both execution and dropped work. Test enqueue/close ordering, a chunk with no author root during collection, external abort, and realm end before the queued write.

Blink's [PipeToReadRequest::ChunkSteps](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/streams/pipe_to_engine.cc) queues the write and retains its chunk. WebKit's [StreamPipeToState::waitForPendingReadAndWrite](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/streams/StreamPipeToUtilities.cpp) accounts for a fulfilled read whose write has not started before running shutdown. Take those designs, not their implementation or ownership machinery.

There is a separate reentrant case: Blink and WebKit clear their pending-read flag before invoking the sink and install the write promise afterward. If the first sink write synchronously aborts, cancellation can run before that write settles. Gecko installs a promise for the queued write beforehand and waits for it. With no newer spec involved, follow the two-engine majority, pin it natively, and identify this as source evidence rather than a browser test result.

**Takeaway**: **Scheduling a write also requires coordinating its queued chunk with shutdown; a previous write's promise cannot account for that chunk. Check reentrant timing against the engines separately.**
