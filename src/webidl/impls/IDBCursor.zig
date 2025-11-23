//! Implementation for IDBCursor interface
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
const IDBCursor = interfaces.IDBCursor;

pub const State = IDBCursor.State;

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

/// Getter for source
pub fn get_source(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for direction
pub fn get_direction(instance: *runtime.Instance) ImplError!enums.IDBCursorDirection {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for key
pub fn get_key(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for primaryKey
pub fn get_primaryKey(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for request
pub fn get_request(instance: *runtime.Instance) ImplError!interfaces.IDBRequest {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: delete
pub fn call_delete(instance: *runtime.Instance) ImplError!interfaces.IDBRequest {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: continue
pub fn call_continue(instance: *runtime.Instance, key: *const anyopaque) ImplError!void {
    _ = instance;
    _ = key;
    return error.NotImplemented;
}

/// Operation: continuePrimaryKey
pub fn call_continuePrimaryKey(instance: *runtime.Instance, key: *const anyopaque, primaryKey: *const anyopaque) ImplError!void {
    _ = instance;
    _ = key;
    _ = primaryKey;
    return error.NotImplemented;
}

/// Operation: update
pub fn call_update(instance: *runtime.Instance, value: *const anyopaque) ImplError!interfaces.IDBRequest {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: advance
pub fn call_advance(instance: *runtime.Instance, count: u32) ImplError!void {
    _ = instance;
    _ = count;
    return error.NotImplemented;
}

