//! Implementation for ServiceWorkerGlobalScope interface
//!
//! Spec: Service Workers 4.1 ServiceWorkerGlobalScope
//! https://w3c.github.io/ServiceWorker/#serviceworkerglobalscope-interface
//!
//! The global object of a service worker's realm (Setup
//! ServiceWorkerGlobalScope step 8.1). The worker host
//! (src/html/worker_host.zig, its service kind) runs the worker: its agent,
//! its loop, its script. What is here is the scope's own members: its
//! service worker's registration and ServiceWorker objects
//! (src/service_worker/realm.zig makes them in this realm), skipWaiting(),
//! clients, and the Cookie Store integration (cookieStore). Every event
//! handler - oninstall, onactivate, onfetch, onmessage, oncookiechange and
//! the rest - is the generated one (dom.event_handlers).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const service_worker = @import("service_worker");
const ServiceWorkerGlobalScope = interfaces.ServiceWorkerGlobalScope;

pub const State = ServiceWorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
    SecurityError,
    OutOfMemory,
};

/// The scope's own state.
pub const InternalState = struct {
    /// Lazily initialized CookieStore instance (SameObject)
    cookie_store: ?*runtime.Instance = null,
    allocator: std.mem.Allocator,
};

/// ServiceWorkerGlobalScope's own construction steps: the generated chain
/// runs WorkerGlobalScope's first (its URL, type and policy container are the
/// service worker's, through the worker host's settings).
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = internal;
}

/// ServiceWorkerGlobalScope's own teardown: the generated chain runs
/// WorkerGlobalScope's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// Getter for clients (4.1.1): "the Clients object that is associated with
/// this" - made on first use ([SameObject], kept by the generated getter).
pub fn get_clients(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.Clients.init(instance.ctx.allocator, instance.ctx);
}

/// Getter for registration (4.1.2): this's service worker's containing
/// registration's object in this realm.
pub fn get_registration(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return service_worker.realm.registrationOf(instance);
}

/// Getter for serviceWorker (4.1.3): this's service worker's object in this
/// realm.
pub fn get_serviceWorker(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return service_worker.realm.serviceWorkerOf(instance);
}

/// Getter for cookieStore
/// https://cookiestore.spec.whatwg.org/#dom-serviceworkerglobalscope-cookiestore
///
/// Returns the CookieStore for this service worker's origin.
pub fn get_cookieStore(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return error.NotImplemented;
    // Lazy initialization (SameObject behavior)
    if (internal.cookie_store) |store| return store;
    // [SecureContext]: a service worker's global is always one.
    const cookie_store = interfaces.CookieStore.initWith(
        internal.allocator,
        instance.ctx,
        .{ .is_secure_context = true },
    ) catch return error.OutOfMemory;
    internal.cookie_store = cookie_store;
    return cookie_store;
}

/// Operation: skipWaiting (4.1.4).
pub fn call_skipWaiting(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return service_worker.realm.skipWaiting(instance);
}
