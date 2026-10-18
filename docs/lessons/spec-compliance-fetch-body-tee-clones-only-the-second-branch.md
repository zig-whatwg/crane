# Spec Compliance: Fetch Body Tee Clones Only the Second Branch

**Date**: 2026-10-17
**Lesson**: Fetch's body tee uses structured cloning, while the public default-stream `tee()` shares chunks.

**Why**: Streams exposes two different entry points to the same algorithm: the JavaScript method passes `cloneForBranch2 = false`, while the wrapper used by other specifications passes true. Fetch calls that wrapper when cloning a body.

**What Happened**: Crane's shared tee helper always used the public method's behavior. `Response.clone()` returned the original typed array in both streams. Looking only at the stream method's tests hid the Fetch failure.

**Fix**: Carry the flag through the existing tee state. In the queued chunk steps, serialize and deserialize the second chunk before delivering either branch. Skip cloning if branch two was canceled. If cloning throws, error both branches with the same exception and cancel the source with that exception. Use the existing non-storage structured-serialization operations, rather than a bytes-only copy or a call to a replaceable JavaScript global.

The full algorithms are [ReadableStreamDefaultTee](https://streams.spec.whatwg.org/#abstract-opdef-readablestreamdefaulttee) and [the external-spec tee wrapper](https://streams.spec.whatwg.org/#readablestream-tee). Blink's [TeeEngine](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/streams/tee_engine.cc) shows the same clone-before-delivery and error-and-cancel sequence.

**Takeaway**: **Read the caller's abstract-operation wrapper as well as the public method: an internal flag can change identity, exceptions and cancellation.**
