//! Implementation for IDBKeyRange interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const IDBKeyRange = @import("interfaces").IDBKeyRange;

pub const State = IDBKeyRange.State;

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

/// Getter for lower
pub fn get_lower(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for upper
pub fn get_upper(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for lowerOpen
pub fn get_lowerOpen(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for upperOpen
pub fn get_upperOpen(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: only
pub fn call_only(instance: *runtime.Instance, value: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: lowerBound
pub fn call_lowerBound(instance: *runtime.Instance, lower: anyopaque, open: bool) ImplError!anyopaque {
    _ = instance;
    _ = lower;
    _ = open;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: upperBound
pub fn call_upperBound(instance: *runtime.Instance, upper: anyopaque, open: bool) ImplError!anyopaque {
    _ = instance;
    _ = upper;
    _ = open;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: bound
pub fn call_bound(instance: *runtime.Instance, lower: anyopaque, upper: anyopaque, lowerOpen: bool, upperOpen: bool) ImplError!anyopaque {
    _ = instance;
    _ = lower;
    _ = upper;
    _ = lowerOpen;
    _ = upperOpen;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: includes
pub fn call_includes(instance: *runtime.Instance, key: anyopaque) ImplError!bool {
    _ = instance;
    _ = key;
    // TODO: Implement operation
    return error.NotImplemented;
}

