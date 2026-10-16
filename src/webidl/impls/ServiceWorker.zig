//! Implementation for ServiceWorker interface
//!
//! Spec: Service Workers 3.1 ServiceWorker
//! https://w3c.github.io/ServiceWorker/#serviceworker-interface
//!
//! A ServiceWorker object represents a service worker; several, across
//! realms, can represent one. Its realm's environment
//! (src/service_worker/realm.zig, "get the service worker object") makes it
//! with the worker's state as a construction argument - its script url and
//! the state it was last set to, which the environment sets as Update Worker
//! State's tasks run - and this impl owns that state. onstatechange and
//! onerror are the generated event handlers (dom.event_handlers).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const service_worker = @import("service_worker");
const ServiceWorker = interfaces.ServiceWorker;

pub const State = ServiceWorker.State;

pub const ImplError = error{
    NotImplemented,
};

/// Its service worker: what its realm's environment gives it.
pub const construction_args = .{"service_worker"};

pub const InternalState = struct {
    /// The service worker's state as this object sees it. OWNED.
    worker: *service_worker.ServiceWorkerObject,
    allocator: std.mem.Allocator,
};

/// ServiceWorker's own construction steps: the generated chain runs
/// EventTarget's first. `args.service_worker` is taken.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    if (!@hasField(@TypeOf(args), "service_worker")) return;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .worker = args.service_worker, .allocator = allocator };
    instance.getState(State).own._internal = internal;
}

/// ServiceWorker's own teardown: the generated chain runs EventTarget's
/// after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.worker.destroy();
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

fn workerOf(instance: *runtime.Instance) !*service_worker.ServiceWorkerObject {
    const internal = instance.getState(State).own._internal orelse return error.NotImplemented;
    return internal.worker;
}

/// Getter for scriptURL (3.1.2): the service worker's serialized script url.
pub fn get_scriptURL(instance: *runtime.Instance) anyerror!runtime.USVString {
    return instance.ctx.allocator.dupe(u8, (try workerOf(instance)).script_url);
}

/// Getter for state (3.1.3): "the value (in ServiceWorkerState enumeration)
/// to which it was last set".
pub fn get_state(instance: *runtime.Instance) anyerror!enums.ServiceWorkerState {
    return switch ((try workerOf(instance)).state) {
        .parsed => ._parsed_,
        .installing => ._installing_,
        .installed => ._installed_,
        .activating => ._activating_,
        .activated => ._activated_,
        .redundant => ._redundant_,
    };
}

/// Operation: postMessage (3.1.4-3.1.5) - service worker messaging is the
/// next batch (Clients, ExtendableMessageEvent).
pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
    _ = instance;
    _ = message;
    _ = transfer;
    return error.NotImplemented;
}
