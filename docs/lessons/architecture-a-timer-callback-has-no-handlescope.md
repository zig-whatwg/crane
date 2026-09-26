# Architecture: A timer callback has no HandleScope

**Date**: 2026-09-22
**Lesson**: Any code path that reaches V8 without being called FROM JavaScript must open its own `HandleScope`.

**Why**: V8 opens a scope around a callback it invokes, so an impl reached from
script always has one. A libuv timer callback is entered from the event loop,
not from V8, and `HandleScope::CreateHandle` does not fail politely without one:

    # Fatal error in v8::HandleScope::CreateHandle()
    # Cannot create a handle without a HandleScope

That is an abort. The journal records one CRASH row with zero subtests and no
message pointing anywhere near the cause.

**What Happened**: `WebSocket`'s pump runs as a self-rearming one-shot timer so
that frames are drained on each turn of the event loop. Nothing in the pump asks
V8 for a Local directly - `EventTarget.dispatchEvent` does, several frames down,
when it wraps the event to hand to a listener. So the code read as pure Zig and
died on its first dispatch.

**Fix**: one scope at the timer entry point, wrapping the whole turn:

```zig
const isolate = ffi.v8_Isolate_GetCurrent() orelse ...;
const scope = ffi.v8_HandleScope_New(isolate) orelse ...;
defer ffi.v8_HandleScope_Dispose(scope);
```

Nested scopes (`invokeIdlHandler` opens its own) are fine, and Globals created
inside outlive it, so wrapping the whole turn costs nothing.

**Takeaway**: **Ask who called you, not what you touch.** If the answer is "the
event loop" rather than "script", the scope is yours to open - and grep for
`setTimeout(` with a Zig callback before trusting any impl that reaches V8.
