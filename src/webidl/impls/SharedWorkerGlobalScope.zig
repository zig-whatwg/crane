//! Implementation for SharedWorkerGlobalScope interface
//!
//! Spec: HTML Standard § 10.2.4.2 The SharedWorkerGlobalScope interface
//! https://html.spec.whatwg.org/#sharedworkerglobalscope
//!
//! The global scope object inside a shared worker. Extends WorkerGlobalScope
//! with shared worker-specific functionality like the name attribute and
//! connect event.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SharedWorkerGlobalScope = interfaces.SharedWorkerGlobalScope;

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const InternalSharedWorker = workers.SharedWorker;

pub const State = SharedWorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    WorkerClosed,
};

/// Internal state for SharedWorkerGlobalScope implementation
///
/// Contains a reference to the backing SharedWorker.
pub const InternalState = struct {
    /// Reference to the shared worker (not owned)
    shared_worker: ?*InternalSharedWorker = null,

    /// Worker name
    name: []const u8 = "",

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        // We don't own the shared_worker, so don't deinit it
        _ = self;
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Initialize with a backing shared worker
pub fn initWithWorker(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    shared_worker: *InternalSharedWorker,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state
    const internal_state = try allocator.create(InternalState);
    internal_state.* = .{
        .shared_worker = shared_worker,
        .name = shared_worker.getName(),
        .allocator = allocator,
    };

    // Store internal state
    var state = instance.getState(State);
    state.own._internal = internal_state;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for name
///
/// Spec: HTML Standard § 10.2.4.2
/// "The name attribute must return the SharedWorkerGlobalScope object's name."
/// This is the name provided in the SharedWorker constructor.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return runtime.DOMString.initInterned(internal.name);
    }
    return runtime.DOMString.initEmpty();
}

/// Getter for onconnect
///
/// Spec: HTML Standard § 10.2.4.2
/// "The onconnect attribute is an event handler IDL attribute whose event handler
/// event type is connect."
/// This event fires when a new context connects to the shared worker.
pub fn get_onconnect(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onconnect;
}

/// Setter for onconnect
pub fn set_onconnect(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onconnect = value;
}

/// Operation: close
///
/// Spec: HTML Standard § 10.2.4.2 close()
/// "The close() method, when invoked, must run these steps:
/// 1. Discard any tasks that have been added to this's relevant agent's event loop's task queues.
/// 2. Set this's closing flag to true."
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.shared_worker) |worker| {
            worker.close();
        }
    }
}
