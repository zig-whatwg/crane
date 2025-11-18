//! Implementation for WebTransportSendStream interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportSendStream = @import("interfaces").WebTransportSendStream;

pub const State = WebTransportSendStream.State;

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

/// Constructor implementation
pub fn constructor(instance: *runtime.Instance, underlyingSink: anyopaque, strategy: anyopaque) !void {
    _ = instance;
    _ = underlyingSink;
    _ = strategy;
    // TODO: Implement constructor logic
}

/// Getter for locked
pub fn get_locked(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for sendGroup
pub fn get_sendGroup(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for sendOrder
pub fn get_sendOrder(instance: *runtime.Instance) ImplError!i64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for sendGroup
pub fn set_sendGroup(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Setter for sendOrder
pub fn set_sendOrder(instance: *runtime.Instance, value: i64) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

/// Operation: abort
pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = reason;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getWriter
pub fn call_getWriter(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getStats
pub fn call_getStats(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getWriter
pub fn call_getWriter(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

