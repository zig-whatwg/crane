//! Implementation for Crypto interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const Crypto = @import("interfaces").Crypto;

pub const State = Crypto.State;

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

/// Getter for subtle
pub fn get_subtle(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: getRandomValues
pub fn call_getRandomValues(instance: *runtime.Instance, array: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = array;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: randomUUID
pub fn call_randomUUID(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

