//! Implementation for SharedWorkerGlobalScope interface
//!
//! Spec: HTML Standard § 10.2.2.3 Shared workers and the
//! SharedWorkerGlobalScope interface
//! https://html.spec.whatwg.org/multipage/workers.html#shared-workers-and-the-sharedworkerglobalscope-interface
//!
//! The global object of a shared worker's realm ("run a worker" step 5, when
//! `is shared`). The worker host (src/html/worker_host.zig) runs the worker:
//! its agent, its tasks, its `connect` events, its end. What is here is the
//! scope's own members - its name, `onconnect`, close().

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SharedWorkerGlobalScope = interfaces.SharedWorkerGlobalScope;

// Ancestors: a SharedWorkerGlobalScope IS a WorkerGlobalScope and an
// EventTarget, and reaches their state through their impls.
const WorkerGlobalScopeImpl = @import("WorkerGlobalScope.zig");
const EventTargetImpl = @import("EventTarget.zig");

/// The worker host: the side of "run a worker" that owns this scope's agent.
const worker_host = @import("html").worker_host;

pub const State = SharedWorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    WorkerClosed,
};

/// The scope's own state.
pub const InternalState = struct {
    /// HTML: the global scope's name - options["name"] of the SharedWorker
    /// that started the worker ("run a worker" step 8). OWNED.
    name: []const u8,

    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        self.allocator.free(self.name);
    }
};

/// Initialize instance.
///
/// Chains to WorkerGlobalScope, and so to EventTarget. When `ctx` is the realm
/// of a worker the host is running, the scope takes that worker's name.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try WorkerGlobalScopeImpl.init(allocator, StateType, vtable, ctx);
    errdefer WorkerGlobalScopeImpl.deinit(instance);
    if (worker_host.scopeSettings(ctx)) |settings| {
        const internal_state = try allocator.create(InternalState);
        errdefer allocator.destroy(internal_state);
        internal_state.* = .{
            .name = try allocator.dupe(u8, settings.name),
            .allocator = allocator,
        };
        instance.getState(State).own._internal = internal_state;
    }
    return instance;
}

/// Deinitialize instance.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    WorkerGlobalScopeImpl.deinit(instance);
}

/// Getter for name: "The name getter steps are to return this's name."
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return try runtime.DOMString.initDupe(instance.ctx.allocator, internal.name);
    }
    return runtime.DOMString.initEmpty();
}

// Event handler IDL attribute (HTML §8.1.8.1): its value lives in
// EventTarget's event handler map, where the host's `connect` event finds it.

/// Getter for onconnect
pub fn get_onconnect(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "connect");
}

/// Setter for onconnect
pub fn set_onconnect(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "connect", value);
}

/// Operation: close
///
/// Spec: HTML Standard, SharedWorkerGlobalScope close(): "1. Discard any
/// tasks that have been added to this's relevant agent's event loop's task
/// queues. 2. Set this's closing flag to true." The worker host keeps the
/// agent's event loop, so it runs both steps - and, the flag set, the scope
/// is no longer found by a SharedWorker constructor.
pub fn call_close(instance: *runtime.Instance) anyerror!void {
    worker_host.closeScope(instance.ctx);
}
