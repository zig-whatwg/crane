//! Implementation for Cache interface
//!
//! Spec: Service Workers 5.4 Cache
//! https://w3c.github.io/ServiceWorker/#cache-interface
//!
//! A Cache object represents one request response list of its Browser's
//! Cache Storage - several objects, in several realms, can represent the
//! same one. CacheStorage.open() makes it with the list as a construction
//! argument (service_worker.cache.api.CacheHandle); its members are the
//! service_worker module's (src/service_worker/cache/api.zig), and the
//! lists are kept in the Browser's store (cache/store.zig).

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
const Cache = interfaces.Cache;

pub const State = Cache.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
};

/// The request response list it represents.
pub const construction_args = .{"cache"};

pub const InternalState = struct {
    handle: api.CacheHandle,
    allocator: std.mem.Allocator,
};

/// Cache's own construction steps: the list is held for as long as the
/// object lives (a deleted cache stays functional for it).
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    if (!@hasField(@TypeOf(args), "cache")) return;
    const handle: api.CacheHandle = args.cache;
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    try handle.storage.retain(handle.cache);
    internal.* = .{ .handle = handle, .allocator = allocator };
    instance.getState(State).own._internal = internal;
}

/// Cache's own teardown.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.handle.storage.release(internal.handle.cache);
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

fn handleOf(instance: *runtime.Instance) !api.CacheHandle {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return internal.handle;
}

fn optionsOf(options: webidl.Opt(dictionaries.CacheQueryOptions)) ?dictionaries.CacheQueryOptions {
    return if (options.was_passed) options.value else null;
}

/// Operation: match (5.4.1).
pub fn call_match(instance: *runtime.Instance, request: typedefs.RequestInfo, options: webidl.Opt(dictionaries.CacheQueryOptions)) anyerror!runtime.JSValue {
    return api.match(instance, try handleOf(instance), request, optionsOf(options));
}

/// Operation: matchAll (5.4.2).
pub fn call_matchAll(instance: *runtime.Instance, request: webidl.Opt(typedefs.RequestInfo), options: webidl.Opt(dictionaries.CacheQueryOptions)) anyerror!runtime.JSValue {
    return api.matchAll(instance, try handleOf(instance), if (request.was_passed) request.value else null, optionsOf(options));
}

/// Operation: add (5.4.3).
pub fn call_add(instance: *runtime.Instance, request: typedefs.RequestInfo) anyerror!runtime.JSValue {
    return api.add(instance, try handleOf(instance), request);
}

/// Operation: addAll (5.4.4).
pub fn call_addAll(instance: *runtime.Instance, requests: runtime.JSValue) anyerror!runtime.JSValue {
    return api.addAll(instance, try handleOf(instance), requests);
}

/// Operation: put (5.4.5).
pub fn call_put(instance: *runtime.Instance, request: typedefs.RequestInfo, response: *runtime.Instance) anyerror!runtime.JSValue {
    return api.put(instance, try handleOf(instance), request, response);
}

/// Operation: delete (5.4.6).
pub fn call_delete(instance: *runtime.Instance, request: typedefs.RequestInfo, options: webidl.Opt(dictionaries.CacheQueryOptions)) anyerror!runtime.JSValue {
    return api.delete(instance, try handleOf(instance), request, optionsOf(options));
}

/// Operation: keys (5.4.7).
pub fn call_keys(instance: *runtime.Instance, request: webidl.Opt(typedefs.RequestInfo), options: webidl.Opt(dictionaries.CacheQueryOptions)) anyerror!runtime.JSValue {
    return api.keys(instance, try handleOf(instance), if (request.was_passed) request.value else null, optionsOf(options));
}
