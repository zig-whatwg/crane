//! Implementation for HTMLAllCollection interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const HTMLAllCollection = @import("interfaces").HTMLAllCollection;

pub const State = HTMLAllCollection.State;

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

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: unnamed
pub fn call_unnamed(instance: *runtime.Instance, index: u32) ImplError!anyopaque {
    _ = instance;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: namedItem
pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = name;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: item
pub fn call_item(instance: *runtime.Instance, nameOrIndex: runtime.DOMString) ImplError!anyopaque {
    _ = instance;
    _ = nameOrIndex;
    // TODO: Implement operation
    return error.NotImplemented;
}

