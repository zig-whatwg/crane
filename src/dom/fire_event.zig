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
const engine = @import("engine");
const any_world = @import("event_dispatch.zig").DispatchPath.any_world;

pub const Implementation = struct {
    dispatch_trusted_with_throws: *const fn (*runtime.Instance, *runtime.Instance, *bool) anyerror!bool,
    dispatch_trusted: *const fn (target: *runtime.Instance, event: *runtime.Instance) anyerror!bool,
    /// `dispatch_trusted` with DOM dispatch's "legacy target override flag"
    /// set: `window` is a Window, and its associated Document is the event's
    /// target while the Window's listeners run (DOM dispatch steps 5, 6.3).
    dispatch_trusted_legacy_target_override: *const fn (window: *runtime.Instance, event: *runtime.Instance) anyerror!bool,
    /// `dispatch_trusted` reaching only the listeners of isolated world
    /// `world` (engine.WorldId; the main world is 0): a user agent's error
    /// report (`dispatchTrustedInWorld`).
    dispatch_trusted_in_world: *const fn (target: *runtime.Instance, event: *runtime.Instance, world: u32) anyerror!bool,
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

/// The world a user agent's report of script of `realm` is dispatched to
/// (`dispatchTrustedInWorld`): the realm's isolated world (engine section
/// 4.2a) - or every listener (`DispatchPath.any_world`), with no check per
/// listener at all, for a Browser that made no isolated world. THE FAST
/// PATH: one load of BrowserScope.isolated_worlds_active.
pub fn reportWorldOf(realm: runtime.Context) u32 {
    const scope = realm.browserScope() orelse return any_world;
    if (!scope.isolated_worlds_active.load(.monotonic)) return any_world;
    return engine.worldOf(realm);
}

/// Dispatch `event` at `target` with isTrusted true, to the listeners of
/// world `world` only (engine section 4.2a: 0 is the main world) - HTML
/// "report an exception"'s error event, which Blink's ErrorEvent keeps for
/// the world of the script that threw: a listener of another world is
/// skipped (ErrorEvent::CanBeDispatchedInWorld, JSBasedEventListener::
/// Invoke). `DispatchPath.any_world` reaches every listener (`reportWorldOf`).
pub fn dispatchTrustedInWorld(target: *runtime.Instance, event: *runtime.Instance, world: u32) !bool {
    const impl = implementation.get() orelse return error.NotSupported;
    return impl.dispatch_trusted_in_world(target, event, world);
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
