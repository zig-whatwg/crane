# Spec Compliance: window.postMessage had never delivered a message

**Date**: 2026-09-22
**Lesson**: Three defects were stacked in `Window.call_postMessage`, and the
first hid the other two. The event it built was never initialized, so
`dispatchEvent` threw `InvalidStateError` on EVERY call, for every message
type, from every window.

**Why**: `createPostMessageEvent` built its MessageEvent through `init`, which
never creates the inherited Event state or sets the initialized flag - the
stateless-`init` shape from [architecture-a-codegen-stub-init-silently-produces-a](architecture-a-codegen-stub-init-silently-produces-a.md), one layer further out. Behind
it: dispatch was synchronous where step 8 of the window post message steps
queues a task, and the message was never serialized (step 7) - the event kept
the argument handle the binding disposes when the call returns.

**What Happened**: 56 `moving-between-documents/` files and about 90 more hung.
The scripting agent traced the ordering: the child iframe posts to its parent
while it parses, which in Crane happens inside the parent's `appendChild`,
before the parent's `addEventListener("message", ...)` line has run. A
four-case probe - `postMessage` of an object, a string, a number and a
function - then threw the same `InvalidStateError` for all four, which turned
"a timing problem" into "this has never worked".

Two more defects in the same event would have surfaced the moment a message
was delivered: `MessageEvent.get_origin` returned its own field (the binding
frees a returned `USVString`, so the first read of `e.origin` freed it, the
second read freed memory, and `deinit` freed it again), and after dispatch the
event was pulled from the wrapper cache and freed, so
`await new Promise(r => addEventListener("message", r))` read a freed event.

**Fix**: serialize at the call through a `ValueSerializer::Delegate` that
throws a "DataCloneError" DOMException (V8's default is a plain Error; Blink
supplies the same delegate), report code 3 when the exception is already
pending so the impl returns `error.ExceptionPending`; queue a task on the
target's loop, holding both windows as (address, slab generation);
deserialize into the target realm inside a `JsScope`; and hand the event to
GC, releasing it only if nothing wrapped it - checked by slab generation
first, since a GC during dispatch may already have collected it. `Task.drop`
frees a message still queued when the page ends.

**Takeaway**: **When a whole directory hangs on one API, call that API with
the four plainest arguments before reading any test.** A probe that
enumerates input types separates "never worked" from "works except when",
and the two need different fixes.
