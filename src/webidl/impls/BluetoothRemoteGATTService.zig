//! Implementation for BluetoothRemoteGATTService interface
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
const BluetoothRemoteGATTService = interfaces.BluetoothRemoteGATTService;

pub const State = BluetoothRemoteGATTService.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
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

/// Getter for device
pub fn get_device(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for uuid
pub fn get_uuid(instance: *runtime.Instance) ImplError!typedefs.UUID {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for isPrimary
pub fn get_isPrimary(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncharacteristicvaluechanged
pub fn get_oncharacteristicvaluechanged(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onserviceadded
pub fn get_onserviceadded(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onservicechanged
pub fn get_onservicechanged(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onserviceremoved
pub fn get_onserviceremoved(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for oncharacteristicvaluechanged
pub fn set_oncharacteristicvaluechanged(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onserviceadded
pub fn set_onserviceadded(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onservicechanged
pub fn set_onservicechanged(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for onserviceremoved
pub fn set_onserviceremoved(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: getCharacteristic
pub fn call_getCharacteristic(instance: *runtime.Instance, characteristic: typedefs.BluetoothCharacteristicUUID) ImplError!*const anyopaque {
    _ = instance;
    _ = characteristic;
    return error.NotImplemented;
}

/// Operation: getIncludedServices
pub fn call_getIncludedServices(instance: *runtime.Instance, service: typedefs.BluetoothServiceUUID) ImplError!*const anyopaque {
    _ = instance;
    _ = service;
    return error.NotImplemented;
}

/// Operation: getCharacteristics
pub fn call_getCharacteristics(instance: *runtime.Instance, characteristic: typedefs.BluetoothCharacteristicUUID) ImplError!*const anyopaque {
    _ = instance;
    _ = characteristic;
    return error.NotImplemented;
}

/// Operation: getIncludedService
pub fn call_getIncludedService(instance: *runtime.Instance, service: typedefs.BluetoothServiceUUID) ImplError!*const anyopaque {
    _ = instance;
    _ = service;
    return error.NotImplemented;
}

