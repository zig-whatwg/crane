//! Implementation for ReadableStreamGenericReader interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ReadableStreamGenericReader = @import("interfaces").ReadableStreamGenericReader;

pub const State = ReadableStreamGenericReader.State;

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

/// Getter for closed
pub fn get_closed(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: cancel
pub fn call_cancel(instance: *runtime.Instance, reason: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = reason;
    // TODO: Implement operation
    return error.NotImplemented;
}

