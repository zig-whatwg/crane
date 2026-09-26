# Architecture: An object the engine makes for a Zig holder must be wrapped or pinned

**Date**: 2026-09-25
**Lesson**: A reader the engine acquired natively and never wrapped leaked. A dependent AbortSignal held only by a Request's `state.own.signal` leaked when nothing read it, and was freed under its Request when script had read it and dropped it.

**Fix**: wrap engine-made streams objects, as ReadableStreamTee and pipeTo do; pin children the owner points to (`same_object.Pin`); and any caller that outlives the owner holds a pin of its own - `fetch()`'s Call does, per DOM §3.3.1 (when an AbortSignal must not be collected) and Blink's `Request::Trace` of `signal_`.

**Takeaway**: **Before you store a pointer to an Instance, decide whether the wrapper cache or a pin keeps it alive. With neither it leaks; with only a weak wrapper it is freed under you.**
