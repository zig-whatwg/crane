//! Implementation for SmartCardContext interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const SmartCardContext = @import("interfaces").SmartCardContext;

pub const State = SmartCardContext.State;

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

/// Operation: listReaders
pub fn call_listReaders(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getStatusChange
pub fn call_getStatusChange(instance: *runtime.Instance, readerStates: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = readerStates;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: connect
pub fn call_connect(instance: *runtime.Instance, readerName: runtime.DOMString, accessMode: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = readerName;
    _ = accessMode;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

