//! Implementation for IDBFactory interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const IDBFactory = @import("interfaces").IDBFactory;

pub const State = IDBFactory.State;

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

/// Operation: open
pub fn call_open(instance: *runtime.Instance, name: runtime.DOMString, version: u64) ImplError!anyopaque {
    _ = instance;
    _ = name;
    _ = version;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteDatabase
pub fn call_deleteDatabase(instance: *runtime.Instance, name: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = name;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: databases
pub fn call_databases(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cmp
pub fn call_cmp(instance: *runtime.Instance, first: anyopaque, second: anyopaque) ImplError!i16 {
    _ = instance;
    _ = first;
    _ = second;
    // TODO: Implement operation
    return error.NotImplemented;
}

