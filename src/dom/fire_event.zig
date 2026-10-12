//! DOM 2.10 "firing events": the user agent's own dispatch, and what the
//! dispatcher keeps while it runs.
//!
//! Script's `dispatchEvent()` initializes isTrusted to false (DOM 2.8 step
//! 2); an event the engine fires - a script's load, an abort, a message, a
//! reported error - is dispatched with isTrusted true. Every engine fire site
//! went through `call_dispatchEvent`, so every one of them read
//! `isTrusted === false`.
//!
//! EventTarget installs the implementation, and every fire site reaches the
//! dispatcher here - an impl in EventTarget's own hierarchy (Node,
//! AbortSignal, Worker, ...) included: the impls boundary has no ancestor
//! exception (AGENTS.md).
//!
//! lint-impls: hook for EventTarget
const process_start = @import("process_start.zig");

const runtime = @import("runtime");

pub const Implementation = struct {
    dispatch_trusted_with_throws: *const fn (*runtime.Instance, *runtime.Instance, *bool) anyerror!bool,
    dispatch_trusted: *const fn (target: *runtime.Instance, event: *runtime.Instance) anyerror!bool,
    /// `window`'s current event (HTML), which inner invoke sets around each
    /// listener it calls in that Window's realm; null for undefined.
    current_event: *const fn (window: *runtime.Instance) ?*runtime.Instance,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by EventTarget's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Dispatch `event` at `target` with isTrusted true. Every target exists, so
/// EventTarget has installed the implementation.
pub fn dispatchTrusted(target: *runtime.Instance, event: *runtime.Instance) !bool {
    const impl = implementation orelse return error.NotSupported;
    return impl.dispatch_trusted(target, event);
}

/// HTML: a Window's "current event", which `window.event` returns - the
/// event whose listener is running in that Window's realm, or null
/// (undefined) when there is none.
pub fn currentEvent(window: *runtime.Instance) ?*runtime.Instance {
    const impl = implementation orelse return null;
    return impl.current_event(window);
}

/// DOM dispatch with legacyOutputDidListenersThrowFlag, used by IndexedDB.
/// The boolean return still reports cancellation; did_throw reports throws.
pub fn dispatchTrustedWithThrows(target: *runtime.Instance, event: *runtime.Instance, did_throw: *bool) !bool {
    const impl = implementation orelse return error.NotSupported;
    return impl.dispatch_trusted_with_throws(target, event, did_throw);
}
