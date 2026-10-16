//! Implementation for CacheStorage interface
//!
//! Spec: Service Workers 5.5 CacheStorage
//! https://w3c.github.io/ServiceWorker/#cachestorage-interface
//!
//! A global's `caches`: the name to cache map of its relevant settings
//! object's storage key, in its Browser's Cache Storage - which every
//! CacheStorage object of that storage key, in every realm and thread of
//! the Browser, represents. No state of its own: the storage key is read
//! from the relevant settings object at each call, and the members are the
//! service_worker module's (src/service_worker/cache/api.zig).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const service_worker = @import("service_worker");
const api = service_worker.cache.api;
const CacheStorage = interfaces.CacheStorage;

pub const State = CacheStorage.State;

pub const ImplError = error{
    NotImplemented,
};

/// No state of its own.
pub const InternalState = struct {};

/// Operation: match (5.5.1).
pub fn call_match(instance: *runtime.Instance, request: typedefs.RequestInfo, options: webidl.Opt(dictionaries.MultiCacheQueryOptions)) anyerror!runtime.JSValue {
    return api.storageMatch(instance, request, if (options.was_passed) options.value else null);
}

/// Operation: has (5.5.2).
pub fn call_has(instance: *runtime.Instance, cacheName: runtime.DOMString) anyerror!runtime.JSValue {
    return api.storageHas(instance, cacheName.asSlice());
}

/// Operation: open (5.5.3).
pub fn call_open(instance: *runtime.Instance, cacheName: runtime.DOMString) anyerror!runtime.JSValue {
    return api.storageOpen(instance, cacheName.asSlice());
}

/// Operation: delete (5.5.4).
pub fn call_delete(instance: *runtime.Instance, cacheName: runtime.DOMString) anyerror!runtime.JSValue {
    return api.storageDelete(instance, cacheName.asSlice());
}

/// Operation: keys (5.5.5).
pub fn call_keys(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return api.storageKeys(instance);
}
