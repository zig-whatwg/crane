//! DOM 2.10 "firing events": the user agent's own dispatch.
//!
//! Script's `dispatchEvent()` initializes isTrusted to false (DOM 2.8 step
//! 2); an event the engine fires - a script's load, an abort, a message, a
//! reported error - is dispatched with isTrusted true. Every engine fire site
//! went through `call_dispatchEvent`, so every one of them read
//! `isTrusted === false`.
//!
//! EventTarget installs the implementation. An impl in EventTarget's own
//! hierarchy (Node, AbortSignal, Worker, ...) calls
//! `EventTargetImpl.dispatchTrusted` directly; code outside it fires here.
//!
//! lint-impls: hook for EventTarget

const runtime = @import("runtime");

pub const Implementation = struct {
    dispatch_trusted: *const fn (target: *runtime.Instance, event: *runtime.Instance) anyerror!bool,
};

/// Per thread: a worker's targets fire on its own thread.
threadlocal var implementation: ?Implementation = null;

/// Called by EventTarget. Idempotent.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// Dispatch `event` at `target` with isTrusted true. Every target exists, so
/// EventTarget has installed the implementation.
pub fn dispatchTrusted(target: *runtime.Instance, event: *runtime.Instance) !bool {
    const impl = implementation orelse return error.NotSupported;
    return impl.dispatch_trusted(target, event);
}
