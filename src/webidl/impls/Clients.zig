//! Implementation for Clients interface
//!
//! Spec: Service Workers 4.3 Clients
//! https://w3c.github.io/ServiceWorker/#clients-interface
//!
//! A service worker global's `clients`. Its members are the service_worker
//! module's (src/service_worker/realm.zig): get() and matchAll() ask the
//! Browser's manager, which gathers each window client's data on that
//! window's own event loop; claim() runs on the manager's job thread.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const service_worker = @import("service_worker");
const Clients = interfaces.Clients;

pub const State = Clients.State;

pub const ImplError = error{
    NotImplemented,
};

/// No state of its own: its realm's environment is the module's.
pub const InternalState = struct {};

/// Operation: get(id) (4.3.1).
pub fn call_get(instance: *runtime.Instance, id: runtime.DOMString) anyerror!runtime.JSValue {
    return service_worker.realm.getClient(instance, id.asSlice());
}

/// Operation: matchAll(options) (4.3.2): ClientQueryOptions'
/// includeUncontrolled (false) and type ("window").
pub fn call_matchAll(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ClientQueryOptions)) anyerror!runtime.JSValue {
    var include_uncontrolled = false;
    var client_type: service_worker.Manager.ClientType = .window;
    if (options.was_passed) {
        include_uncontrolled = options.value.includeUncontrolled orelse false;
        if (options.value.type) |given| client_type = switch (given) {
            ._window_ => .window,
            ._worker_ => .worker,
            ._sharedworker_ => .sharedworker,
            ._all_ => .all,
        };
    }
    return service_worker.realm.matchAll(instance, include_uncontrolled, client_type);
}

/// Operation: openWindow(url) (4.3.3).
pub fn call_openWindow(instance: *runtime.Instance, url: runtime.USVString) anyerror!runtime.JSValue {
    return service_worker.realm.openWindow(instance, url);
}

/// Operation: claim (4.3.4).
pub fn call_claim(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return service_worker.realm.claim(instance);
}
