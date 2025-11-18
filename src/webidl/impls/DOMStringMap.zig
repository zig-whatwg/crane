//! Implementation for DOMStringMap interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const DOMStringMap = @import("interfaces").DOMStringMap;

pub const State = DOMStringMap.State;

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

/// Operation: unnamed
pub fn call_unnamed(instance: *runtime.Instance, name: runtime.DOMString) ImplError!runtime.DOMString {
    _ = instance;
    _ = name;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: unnamed
pub fn call_unnamed(instance: *runtime.Instance, name: runtime.DOMString, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = name;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: unnamed
pub fn call_unnamed(instance: *runtime.Instance, name: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = name;
    // TODO: Implement operation
    return error.NotImplemented;
}

