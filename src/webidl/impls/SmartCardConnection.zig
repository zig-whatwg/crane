//! Implementation for SmartCardConnection interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const SmartCardConnection = @import("interfaces").SmartCardConnection;

pub const State = SmartCardConnection.State;

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

/// Operation: disconnect
pub fn call_disconnect(instance: *runtime.Instance, disposition: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = disposition;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: transmit
pub fn call_transmit(instance: *runtime.Instance, sendBuffer: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = sendBuffer;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: startTransaction
pub fn call_startTransaction(instance: *runtime.Instance, transaction: anyopaque, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = transaction;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: status
pub fn call_status(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: control
pub fn call_control(instance: *runtime.Instance, controlCode: u32, data: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = controlCode;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getAttribute
pub fn call_getAttribute(instance: *runtime.Instance, tag: u32) ImplError!anyopaque {
    _ = instance;
    _ = tag;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setAttribute
pub fn call_setAttribute(instance: *runtime.Instance, tag: u32, value: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = tag;
    _ = value;
    // TODO: Implement operation
    return error.NotImplemented;
}

