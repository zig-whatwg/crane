//! Implementation for Cache interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const Cache = @import("interfaces").Cache;

pub const State = Cache.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Operation: match
pub fn call_match(instance: *runtime.Instance, request: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = request;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: matchAll
pub fn call_matchAll(instance: *runtime.Instance, request: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = request;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: add
pub fn call_add(instance: *runtime.Instance, request: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = request;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: addAll
pub fn call_addAll(instance: *runtime.Instance, requests: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = requests;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: put
pub fn call_put(instance: *runtime.Instance, request: anyopaque, response: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = request;
    _ = response;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: delete
pub fn call_delete(instance: *runtime.Instance, request: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = request;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: keys
pub fn call_keys(instance: *runtime.Instance, request: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = request;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

