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
const Hook = @import("hook.zig").Hook;

const runtime = @import("runtime");

pub const Implementation = struct {
    dispatch_trusted_with_throws: *const fn (*runtime.Instance, *runtime.Instance, *bool) anyerror!bool,
    dispatch_trusted: *const fn (target: *runtime.Instance, event: *runtime.Instance) anyerror!bool,
    /// `dispatch_trusted` with DOM dispatch's "legacy target override flag"
    /// set: `window` is a Window, and its associated Document is the event's
    /// target while the Window's listeners run (DOM dispatch steps 5, 6.3).
    dispatch_trusted_legacy_target_override: *const fn (window: *runtime.Instance, event: *runtime.Instance) anyerror!bool,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: Hook(?Implementation) = .init(null);

/// Called by EventTarget's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

/// Dispatch `event` at `target` with isTrusted true. Every target exists, so
/// EventTarget has installed the implementation.
pub fn dispatchTrusted(target: *runtime.Instance, event: *runtime.Instance) !bool {
    const impl = implementation.get() orelse return error.NotSupported;
    return impl.dispatch_trusted(target, event);
}

/// Dispatch `event` at the Window `window` with isTrusted true and the
/// legacy target override flag set: HTML fires the Window's load (the end
/// step 9.5), pageshow and pagehide ("fire a page transition event") and
/// unload ("unload" step 12) this way, so `event.target` is the Window's
/// associated Document while `currentTarget` is the Window - as Blink's
/// LocalDOMWindow::DispatchEvent(event, document()).
pub fn dispatchTrustedLegacyTargetOverride(window: *runtime.Instance, event: *runtime.Instance) !bool {
    const impl = implementation.get() orelse return error.NotSupported;
    return impl.dispatch_trusted_legacy_target_override(window, event);
}

/// DOM dispatch with legacyOutputDidListenersThrowFlag, used by IndexedDB.
/// The boolean return still reports cancellation; did_throw reports throws.
pub fn dispatchTrustedWithThrows(target: *runtime.Instance, event: *runtime.Instance, did_throw: *bool) !bool {
    const impl = implementation.get() orelse return error.NotSupported;
    return impl.dispatch_trusted_with_throws(target, event, did_throw);
}
