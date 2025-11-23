//! Implementation for StorageBucketManager interface
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
const StorageBucketManager = interfaces.StorageBucketManager;

pub const State = StorageBucketManager.State;

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
pub fn call_delete(instance: *runtime.Instance, name: runtime.DOMString) ImplError!*const anyopaque {
    _ = instance;
    _ = name;
    return error.NotImplemented;
}

/// Operation: keys
pub fn call_keys(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: open
pub fn call_open(instance: *runtime.Instance, name: runtime.DOMString, options: dictionaries.StorageBucketOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = name;
    _ = options;
    return error.NotImplemented;
}

