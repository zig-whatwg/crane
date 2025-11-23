//! Implementation for Cache interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const Cache = interfaces.Cache;

pub const State = Cache.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Operation: delete
pub fn call_delete(instance: *runtime.Instance, request: typedefs.RequestInfo, options: dictionaries.CacheQueryOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = request;
    _ = options;
    return error.NotImplemented;
}

/// Operation: match
pub fn call_match(instance: *runtime.Instance, request: typedefs.RequestInfo, options: dictionaries.CacheQueryOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = request;
    _ = options;
    return error.NotImplemented;
}

/// Operation: keys
pub fn call_keys(instance: *runtime.Instance, request: typedefs.RequestInfo, options: dictionaries.CacheQueryOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = request;
    _ = options;
    return error.NotImplemented;
}

/// Operation: matchAll
pub fn call_matchAll(instance: *runtime.Instance, request: typedefs.RequestInfo, options: dictionaries.CacheQueryOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = request;
    _ = options;
    return error.NotImplemented;
}

/// Operation: add
pub fn call_add(instance: *runtime.Instance, request: typedefs.RequestInfo) ImplError!*const anyopaque {
    _ = instance;
    _ = request;
    return error.NotImplemented;
}

/// Operation: addAll
pub fn call_addAll(instance: *runtime.Instance, requests: *const anyopaque) ImplError!*const anyopaque {
    _ = instance;
    _ = requests;
    return error.NotImplemented;
}

/// Operation: put
pub fn call_put(instance: *runtime.Instance, request: typedefs.RequestInfo, response: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    _ = request;
    _ = response;
    return error.NotImplemented;
}

