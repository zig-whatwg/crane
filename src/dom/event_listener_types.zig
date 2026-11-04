//! Whether an event target's event listener list holds a listener of a type:
//! the list is EventTarget's state, so EventTarget installs the step once, at
//! process start (its installHooks), and every caller asks here.
//!
//! Service Workers "Run Service Worker" reads it once, when a service worker's
//! script has first run: "for each eventType of settingsObject's global
//! object's associated list of event listeners' event types, append eventType
//! to workerGlobalScope's associated service worker's set of event types to
//! handle" - which Handle Fetch, InstallEvent.addRoutes() and Should Skip
//! Event consult afterwards.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#run-service-worker-algorithm
//!
//! lint-impls: hook for EventTarget
const std = @import("std");
const runtime = @import("runtime");
const Hook = @import("hook.zig").Hook;

/// Whether `target`'s event listener list holds a listener whose type is
/// `event_type` and whose removed is false - an activated event handler's
/// included (its listener is in the list too).
pub const HasListenersOfType = *const fn (target: *runtime.Instance, event_type: []const u8) bool;

// process-wide: a function pointer EventTarget's installHooks writes once at process start, the same for every Browser
var implementation: Hook(?HasListenersOfType) = .init(null);

/// Install the owner's step before any Browser exists.
pub fn install(step: HasListenersOfType) void {
    implementation.install(step);
}

/// Whether `target` has a listener of `event_type` (false while no
/// EventTarget step is installed: no target exists then).
pub fn hasListenersOfType(target: *runtime.Instance, event_type: []const u8) bool {
    const step = implementation.get() orelse return false;
    return step(target, event_type);
}
