//! Implementation for BluetoothRemoteGATTServer interface
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
const BluetoothRemoteGATTServer = interfaces.BluetoothRemoteGATTServer;

pub const State = BluetoothRemoteGATTServer.State;

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

/// Getter for device
pub fn get_device(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for connected
pub fn get_connected(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: disconnect
pub fn call_disconnect(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getPrimaryServices
pub fn call_getPrimaryServices(instance: *runtime.Instance, service: typedefs.BluetoothServiceUUID) ImplError!*const anyopaque {
    _ = instance;
    _ = service;
    return error.NotImplemented;
}

/// Operation: connect
pub fn call_connect(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getPrimaryService
pub fn call_getPrimaryService(instance: *runtime.Instance, service: typedefs.BluetoothServiceUUID) ImplError!*const anyopaque {
    _ = instance;
    _ = service;
    return error.NotImplemented;
}

