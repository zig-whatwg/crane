# Architecture: Erroring or closing a stream frees its source mid-call

**Date**: 2026-09-25
**Lesson**: `byteControllerError` and `byteControllerClose` clear the source's algorithms, which runs the source's deinit before the call returns.

**Why**: PipeStream's deinit releases the pipe, which frees the PipeSource, which disposes the abort reason it holds.

**What Happened**: in the networking lane's streamed bodies (increment 3), erroring an aborted body with its own reason segfaulted in `JSPromise::Reject`: the reason had been disposed during the very call that was using it.

**Fix**: clone the reason before erroring, and hold a `busy` flag across any controller call.

**Takeaway**: **Any controller call can free the source that made it. Copy what you pass in first.**
