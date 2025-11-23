//! Implementation for RTCSctpTransport interface
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
const RTCSctpTransport = interfaces.RTCSctpTransport;

pub const State = RTCSctpTransport.State;

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

/// Getter for transport
pub fn get_transport(instance: *runtime.Instance) ImplError!interfaces.RTCDtlsTransport {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for state
pub fn get_state(instance: *runtime.Instance) ImplError!enums.RTCSctpTransportState {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for maxMessageSize
pub fn get_maxMessageSize(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for maxChannels
pub fn get_maxChannels(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onstatechange
pub fn get_onstatechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onstatechange
pub fn set_onstatechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

