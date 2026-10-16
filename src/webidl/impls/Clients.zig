//! Implementation for Clients interface
//!
//! Spec: Service Workers 4.3 Clients
//! https://w3c.github.io/ServiceWorker/#clients-interface
//!
//! A service worker global's `clients`. claim() is the service_worker
//! module's (src/service_worker/realm.zig: its steps run on the Browser's
//! service worker job thread); get(), matchAll() and openWindow() are the
//! next batch's (the Client objects).

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

/// Operation: get
pub fn call_get(instance: *runtime.Instance, id: runtime.DOMString) anyerror!runtime.JSValue {
    _ = instance;
    _ = id;
    return error.NotImplemented;
}

/// Operation: matchAll
pub fn call_matchAll(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ClientQueryOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: openWindow
pub fn call_openWindow(instance: *runtime.Instance, url: runtime.USVString) anyerror!runtime.JSValue {
    _ = instance;
    _ = url;
    return error.NotImplemented;
}

/// Operation: claim (4.3.4).
pub fn call_claim(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return service_worker.realm.claim(instance);
}
