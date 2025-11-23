//! Implementation for WebTransportDatagramsWritable interface
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
const WebTransportDatagramsWritable = interfaces.WebTransportDatagramsWritable;

pub const State = WebTransportDatagramsWritable.State;

pub const ImplError = error{
    NotImplemented,
};

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
pub fn get_sendGroup(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sendOrder
pub fn get_sendOrder(instance: *runtime.Instance) ImplError!i64 {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for sendGroup
pub fn set_sendGroup(instance: *runtime.Instance, value: *runtime.Instance) ImplError!void {
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

