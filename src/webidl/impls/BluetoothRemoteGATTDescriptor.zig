//! Implementation for BluetoothRemoteGATTDescriptor interface
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
const BluetoothRemoteGATTDescriptor = interfaces.BluetoothRemoteGATTDescriptor;

pub const State = BluetoothRemoteGATTDescriptor.State;

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

/// Getter for characteristic
pub fn get_characteristic(instance: *runtime.Instance) ImplError!interfaces.BluetoothRemoteGATTCharacteristic {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for uuid
pub fn get_uuid(instance: *runtime.Instance) ImplError!typedefs.UUID {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: writeValue
pub fn call_writeValue(instance: *runtime.Instance, value: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: readValue
pub fn call_readValue(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

