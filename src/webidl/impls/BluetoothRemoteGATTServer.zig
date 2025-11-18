//! Implementation for BluetoothRemoteGATTServer interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const BluetoothRemoteGATTServer = @import("interfaces").BluetoothRemoteGATTServer;

pub const State = BluetoothRemoteGATTServer.State;

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

/// Getter for device
pub fn get_device(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for connected
pub fn get_connected(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: connect
pub fn call_connect(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: disconnect
pub fn call_disconnect(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getPrimaryService
pub fn call_getPrimaryService(instance: *runtime.Instance, service: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = service;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getPrimaryServices
pub fn call_getPrimaryServices(instance: *runtime.Instance, service: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = service;
    // TODO: Implement operation
    return error.NotImplemented;
}

