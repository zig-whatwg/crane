//! Implementation for StylePropertyMapReadOnly interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;

pub const State = StylePropertyMapReadOnly.State;

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

/// Getter for size
pub fn get_size(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: get
pub fn call_get(instance: *runtime.Instance, property: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = property;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAll
pub fn call_getAll(instance: *runtime.Instance, property: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = property;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: has
pub fn call_has(instance: *runtime.Instance, property: runtime.DOMString) ImplError!bool {
    _ = instance;
    _ = property;
    // TODO: Implement operation
    return error.NotImplemented;
}

