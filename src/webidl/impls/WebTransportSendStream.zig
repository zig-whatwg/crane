//! Implementation for WebTransportSendStream interface
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
const WebTransportSendStream = interfaces.WebTransportSendStream;

pub const State = WebTransportSendStream.State;

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

/// Getter for sendGroup
pub fn get_sendGroup(instance: *runtime.Instance) ImplError!interfaces.WebTransportSendGroup {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sendOrder
pub fn get_sendOrder(instance: *runtime.Instance) ImplError!i64 {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for sendGroup
pub fn set_sendGroup(instance: *runtime.Instance, value: interfaces.WebTransportSendGroup) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for sendOrder
pub fn set_sendOrder(instance: *runtime.Instance, value: i64) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: getWriter
pub fn call_getWriter(instance: *runtime.Instance) ImplError!interfaces.WebTransportWriter {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getStats
pub fn call_getStats(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

