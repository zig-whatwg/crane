//! EventTarget's read-only event listener queries: whether a target holds a
//! listener of a type (Service Workers), and snapshotting a target's active
//! listeners for CDP `DOMDebugger.getEventListeners`.
//! The list is EventTarget's state, so EventTarget installs the steps once, at
//! process start (its installHooks), and every caller asks here.
//!
//! Service Workers "Run Service Worker" reads `hasListenersOfType` once, when
//! a service worker's script has first run: "for each eventType of
//! settingsObject's global object's associated list of event listeners' event
//! types, append eventType to workerGlobalScope's associated service worker's
//! set of event types to handle" - which Handle Fetch, InstallEvent.addRoutes()
//! and Should Skip Event consult afterwards.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#run-service-worker-algorithm
//!
//! lint-impls: hook for EventTarget
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const Hook = @import("hook.zig").Hook;

/// Whether `target`'s event listener list holds a listener whose type is
/// `event_type` and whose removed is false - an activated event handler's
/// included (its listener is in the list too).
pub const HasListenersOfType = *const fn (target: *runtime.Instance, event_type: []const u8) bool;

/// One active listener on an EventTarget, snapshotted for CDP
/// `DOMDebugger.getEventListeners` (Blink
/// `InspectorDOMDebuggerAgent::CollectEventListeners`). Each entry owns its
/// duplicated `event_type` and its retained `handler` value; free the slice
/// with `deinitSnapshot`.
pub const InspectorListener = struct {
    event_type: []u8,
    capture: bool,
    passive: bool,
    once: bool,
    handler: engine.Owned,
    /// Callback context (realm + world) in which the listener was registered.
    context: ?runtime.Context,
};

/// Snapshot all active listeners of `target` (compiling raw content-attribute
/// event handlers on demand, as Blink's
/// `JSEventHandlerForContentAttribute::GetListenerObject` does).
pub const SnapshotListeners = *const fn (target: *runtime.Instance, allocator: std.mem.Allocator) error{OutOfMemory}![]InspectorListener;

pub const Implementation = struct {
    has_listeners_of_type: HasListenersOfType,
    snapshot_listeners: SnapshotListeners,
};

// process-wide: a hook table EventTarget's installHooks writes once at process start, the same for every Browser
var implementation: Hook(?Implementation) = .init(null);

/// Install the owner's steps before any Browser exists.
pub fn install(impl: Implementation) void {
    implementation.install(impl);
}

/// Whether `target` has a listener of `event_type` (false while no
/// EventTarget step is installed: no target exists then).
pub fn hasListenersOfType(target: *runtime.Instance, event_type: []const u8) bool {
    const impl = implementation.get() orelse return false;
    return impl.has_listeners_of_type(target, event_type);
}

/// Snapshot all active listeners of `target`, owned by `allocator` (free with
/// `deinitSnapshot`). Empty slice while no EventTarget step is installed.
pub fn snapshotListeners(target: *runtime.Instance, allocator: std.mem.Allocator) error{OutOfMemory}![]InspectorListener {
    const impl = implementation.get() orelse return &.{};
    return impl.snapshot_listeners(target, allocator);
}

/// Release every owned type copy and engine handle in a snapshot returned by
/// `snapshotListeners`, and free the slice itself.
pub fn deinitSnapshot(allocator: std.mem.Allocator, entries: []InspectorListener) void {
    for (entries) |entry| {
        allocator.free(entry.event_type);
        entry.handler.release();
    }
    allocator.free(entries);
}
