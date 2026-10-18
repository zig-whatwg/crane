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
//! implementation in its installHooks, before any registration can exist.
//!
//! It is also where the mutation observer algorithms meet an observer's own
//! state (src/dom/mutation_observer_algorithms.zig): its record queue, whose
//! TYPE lives here and whose state the observer keeps, and the invocation of
//! its callback.
//!
//! lint-impls: hook for MutationObserver
const process_start = @import("process_start.zig");

const std = @import("std");
const infra = @import("infra");
const runtime = @import("runtime");
const handles = @import("handles.zig");
const RegisteredObserver = @import("registered_observer.zig").RegisteredObserver;

/// What the MutationObserver impl supplies.
pub const Implementation = struct {
    /// `node` is going away while `observer` - taken at slab generation
    /// `generation` - is registered on it.
    node_released: *const fn (observer: *runtime.Instance, generation: u64, node: *runtime.Instance) void,
    /// A transient registered observer of `observer` (generation
    /// `generation`) has been appended to `node`'s list: "remove" step 15.
    /// The observer remembers the node, to take it off again.
    transient_added: *const fn (observer: *runtime.Instance, generation: u64, node: *runtime.Instance) void,
    /// "Notify mutation observers" step 6.3 for `observer`: remove all its
    /// transient registered observers from the nodes that list them.
    remove_transients: *const fn (observer: *runtime.Instance) void,
    /// `observer`'s record queue, in its state.
    record_queue: *const fn (observer: *runtime.Instance) *RecordQueue,
    /// "Notify mutation observers" step 6.4: invoke `observer`'s callback
    /// with « `records`, `observer` », and "report" what it throws. The
    /// records are taken: wrapped, they are the wrapper cache's.
    invoke_callback: *const fn (observer: *runtime.Instance, records: []const *runtime.Instance) anyerror!void,
};

/// A MutationObserver's record queue (DOM 4.3.1: "a record queue, which is a
/// queue of zero or more MutationRecord objects"). The observer keeps it by
/// value in its state and frees the records still in it when it goes;
/// "queue a mutation record" enqueues to it (step 4.2) and "notify mutation
/// observers" empties it (steps 6.1-6.2).
pub const RecordQueue = struct {
    allocator: std.mem.Allocator,
    /// The records, unwrapped and OWNED until delivered or taken.
    records: std.ArrayListUnmanaged(*runtime.Instance) = .empty,

    /// Enqueue `record`; on failure the caller still owns it.
    pub fn enqueue(self: *RecordQueue, record: *runtime.Instance) error{OutOfMemory}!void {
        try self.records.append(self.allocator, record);
    }

    /// Free the records still queued, and empty the queue.
    pub fn freeRecords(self: *RecordQueue) void {
        for (self.records.items) |record| runtime.Instance.deinit(record);
        self.records.clearRetainingCapacity();
    }

    pub fn deinit(self: *RecordQueue) void {
        self.freeRecords();
        self.records.deinit(self.allocator);
    }
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by MutationObserver's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
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

/// "remove" step 15: a transient registered observer of `observer` now sits
/// in `node`'s registered observer list.
pub fn transientAdded(observer: *runtime.Instance, generation: u64, node: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.transient_added(observer, generation, node);
}

/// "Notify mutation observers" step 6.3: remove all transient registered
/// observers whose observer is `observer`.
pub fn removeTransients(observer: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.remove_transients(observer);
}

/// `observer`'s record queue; null before MutationObserver has installed its
/// steps, when no observer can exist.
pub fn recordQueueOf(observer: *runtime.Instance) ?*RecordQueue {
    const impl = implementation orelse return null;
    return impl.record_queue(observer);
}

/// "Notify mutation observers" step 6.4 for `observer`: see
/// `Implementation.invoke_callback`.
pub fn invokeCallback(observer: *runtime.Instance, records: []const *runtime.Instance) !void {
    const impl = implementation orelse return error.NotSupported;
    return impl.invoke_callback(observer, records);
}
