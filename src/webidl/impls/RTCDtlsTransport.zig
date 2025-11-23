//! Implementation for RTCDtlsTransport interface
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
const RTCDtlsTransport = interfaces.RTCDtlsTransport;

pub const State = RTCDtlsTransport.State;

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

/// Getter for iceTransport
pub fn get_iceTransport(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for state
pub fn get_state(instance: *runtime.Instance) ImplError!enums.RTCDtlsTransportState {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onstatechange
pub fn get_onstatechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onstatechange
pub fn set_onstatechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: getRemoteCertificates
pub fn call_getRemoteCertificates(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

