//! Implementation for IDBKeyRange interface
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
const IDBKeyRange = interfaces.IDBKeyRange;

pub const State = IDBKeyRange.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for this implementation
/// Can be used to store browser-specific data structures
pub const InternalState = struct {};

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

/// Getter for lower
pub fn get_lower(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for upper
pub fn get_upper(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lowerOpen
pub fn get_lowerOpen(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for upperOpen
pub fn get_upperOpen(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: only
pub fn call_only(instance: *runtime.Instance, value: *const anyopaque) ImplError!interfaces.IDBKeyRange {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: includes
pub fn call_includes(instance: *runtime.Instance, key: *const anyopaque) ImplError!bool {
    _ = instance;
    _ = key;
    return error.NotImplemented;
}

/// Operation: bound
pub fn call_bound(instance: *runtime.Instance, lower: *const anyopaque, upper: *const anyopaque, lowerOpen: bool, upperOpen: bool) ImplError!interfaces.IDBKeyRange {
    _ = instance;
    _ = lower;
    _ = upper;
    _ = lowerOpen;
    _ = upperOpen;
    return error.NotImplemented;
}

/// Operation: upperBound
pub fn call_upperBound(instance: *runtime.Instance, upper: *const anyopaque, open: bool) ImplError!interfaces.IDBKeyRange {
    _ = instance;
    _ = upper;
    _ = open;
    return error.NotImplemented;
}

/// Operation: lowerBound
pub fn call_lowerBound(instance: *runtime.Instance, lower: *const anyopaque, open: bool) ImplError!interfaces.IDBKeyRange {
    _ = instance;
    _ = lower;
    _ = open;
    return error.NotImplemented;
}

