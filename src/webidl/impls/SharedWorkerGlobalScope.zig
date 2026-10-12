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

/// SharedWorkerGlobalScope's own construction steps: the generated chain runs WorkerGlobalScope's first.
///
/// When its realm is that of a worker the host is running, the scope takes
/// that worker's name.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    if (worker_host.scopeSettings(instance.ctx)) |settings| {
        const internal_state = try allocator.create(InternalState);
        errdefer allocator.destroy(internal_state);
        internal_state.* = .{
            .name = try allocator.dupe(u8, settings.name),
            .allocator = allocator,
        };
        instance.getState(State).own._internal = internal_state;
    }
}

/// SharedWorkerGlobalScope's own teardown: the generated chain runs WorkerGlobalScope's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
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
