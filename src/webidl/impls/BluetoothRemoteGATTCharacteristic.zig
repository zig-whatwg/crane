//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for BluetoothRemoteGATTCharacteristic interface
//!
//! This file is AUTO-GENERATED into impls_tmp/ directory.
//! The impls_tmp/ directory is gitignored and NOT part of the build.
//!
//! TO USE THIS STUB:
//!   1. Copy this file to src/webidl/impls/
//!   2. Remove this header comment block
//!   3. Add your implementation logic
//!   4. The impls/ directory is the canonical location for implementations
//!
//! If updating an existing implementation:
//!   1. Diff this stub against the existing file in impls/
//!   2. Manually merge new signatures while preserving custom code
//!
//! ============================================================================

const std = @import("std");
const webidl = @import("webidl");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const BluetoothRemoteGATTCharacteristic = interfaces.BluetoothRemoteGATTCharacteristic;

pub const State = BluetoothRemoteGATTCharacteristic.State;

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

/// Getter for service
pub fn get_service(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for uuid
pub fn get_uuid(instance: *runtime.Instance) ImplError!typedefs.UUID {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for properties
pub fn get_properties(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for value
pub fn get_value(instance: *runtime.Instance) ImplError!?*const anyopaque {
    _ = instance;
    return null;
}

/// Getter for oncharacteristicvaluechanged
pub fn get_oncharacteristicvaluechanged(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for oncharacteristicvaluechanged
pub fn set_oncharacteristicvaluechanged(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: startNotifications
pub fn call_startNotifications(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: writeValueWithResponse
pub fn call_writeValueWithResponse(instance: *runtime.Instance, value: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: writeValue
pub fn call_writeValue(instance: *runtime.Instance, value: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: getDescriptors
pub fn call_getDescriptors(instance: *runtime.Instance, descriptor: webidl.Opt(typedefs.BluetoothDescriptorUUID)) ImplError!*const anyopaque {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: getDescriptor
pub fn call_getDescriptor(instance: *runtime.Instance, descriptor: typedefs.BluetoothDescriptorUUID) ImplError!*const anyopaque {
    _ = instance;
    _ = descriptor;
    return error.NotImplemented;
}

/// Operation: writeValueWithoutResponse
pub fn call_writeValueWithoutResponse(instance: *runtime.Instance, value: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: stopNotifications
pub fn call_stopNotifications(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: readValue
pub fn call_readValue(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

