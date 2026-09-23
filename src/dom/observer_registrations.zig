//! DOM § 4.3 a node's registered observer list, as the hook between a node
//! and the MutationObservers registered on it.
//!
//! "Nodes have a strong reference to registered observers in their registered
//! observer list. Registered observers in a node's registered observer list
//! have a weak reference to the node." Crane has no tracing collector to
//! express either, so the MutationObserver impl keeps itself alive while any
//! node lists it (it holds its own wrapper), and a node that goes away tells
//! each observer registered on it here, so the observer can forget the node
//! and let itself go once it observes nothing. The Node impl may not call into
//! the MutationObserver impl; the MutationObserver impl installs the
//! implementation in its `init`, before any registration can exist.
//!
//! lint-impls: hook for MutationObserver

const infra = @import("infra");
const runtime = @import("runtime");
const handles = @import("handles.zig");
const RegisteredObserver = @import("registered_observer.zig").RegisteredObserver;

/// What the MutationObserver impl supplies.
pub const Implementation = struct {
    /// `node` is going away while `observer` - taken at slab generation
    /// `generation` - is registered on it.
    node_released: *const fn (observer: *runtime.Instance, generation: u64, node: *runtime.Instance) void,
};

/// Per thread, like the nodes and observers it serves.
threadlocal var implementation: ?Implementation = null;

/// Called by the MutationObserver impl. Idempotent.
pub fn install(impl: Implementation) void {
    implementation = impl;
}

/// `node` is going away: tell every observer registered on it, then free its
/// registered observer list.
pub fn releaseList(node: *runtime.Instance, list: *infra.List(RegisteredObserver)) void {
    if (implementation) |impl| {
        for (list.items()) |registered| {
            const observer_opaque = handles.mutationObserverToAnyopaque(registered.observer) orelse continue;
            const observer: *runtime.Instance = @ptrCast(@alignCast(observer_opaque));
            impl.node_released(observer, registered.observer_generation, node);
        }
    }
    list.deinit();
}
