//! Implementation for IDBCursorWithValue interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const IDBCursorWithValue = @import("interfaces").IDBCursorWithValue;

pub const State = IDBCursorWithValue.State;

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

/// Getter for source
pub fn get_source(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for direction
pub fn get_direction(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for key
pub fn get_key(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for primaryKey
pub fn get_primaryKey(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for request
pub fn get_request(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: advance
pub fn call_advance(instance: *runtime.Instance, count: u32) ImplError!void {
    _ = instance;
    _ = count;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: continue
pub fn call_continue(instance: *runtime.Instance, key: anyopaque) ImplError!void {
    _ = instance;
    _ = key;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: continuePrimaryKey
pub fn call_continuePrimaryKey(instance: *runtime.Instance, key: anyopaque, primaryKey: anyopaque) ImplError!void {
    _ = instance;
    _ = key;
    _ = primaryKey;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: update
pub fn call_update(instance: *runtime.Instance, value: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: delete
pub fn call_delete(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

