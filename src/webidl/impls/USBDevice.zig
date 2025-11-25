//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for USBDevice interface
//!
//! This file is AUTO-GENERATED into impls_tmp/ directory.
//! The impls_tmp/ directory is gitignored and NOT part of the build.
//!
//! TO USE THIS STUB:
//!   1. Copy this file to src/webidl/impls/
//!   2. Add your implementation logic
//!   3. The impls/ directory is the canonical location for implementations
//!
//! If updating an existing implementation:
//!   1. Diff this stub against the existing file in impls/
//!   2. Manually merge new signatures while preserving custom code
//!
//! ============================================================================

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const USBDevice = interfaces.USBDevice;

pub const State = USBDevice.State;

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

/// Getter for usbVersionMajor
pub fn get_usbVersionMajor(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for usbVersionMinor
pub fn get_usbVersionMinor(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for usbVersionSubminor
pub fn get_usbVersionSubminor(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for deviceClass
pub fn get_deviceClass(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for deviceSubclass
pub fn get_deviceSubclass(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for deviceProtocol
pub fn get_deviceProtocol(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for vendorId
pub fn get_vendorId(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for productId
pub fn get_productId(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for deviceVersionMajor
pub fn get_deviceVersionMajor(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for deviceVersionMinor
pub fn get_deviceVersionMinor(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for deviceVersionSubminor
pub fn get_deviceVersionSubminor(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for manufacturerName
pub fn get_manufacturerName(instance: *runtime.Instance) ImplError!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for productName
pub fn get_productName(instance: *runtime.Instance) ImplError!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for serialNumber
pub fn get_serialNumber(instance: *runtime.Instance) ImplError!?runtime.DOMString {
    _ = instance;
    return null;
}

/// Getter for configuration
pub fn get_configuration(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for configurations
pub fn get_configurations(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for opened
pub fn get_opened(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: releaseInterface
pub fn call_releaseInterface(instance: *runtime.Instance, interfaceNumber: u8) ImplError!*const anyopaque {
    _ = instance;
    _ = interfaceNumber;
    return error.NotImplemented;
}

/// Operation: open
pub fn call_open(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: selectConfiguration
pub fn call_selectConfiguration(instance: *runtime.Instance, configurationValue: u8) ImplError!*const anyopaque {
    _ = instance;
    _ = configurationValue;
    return error.NotImplemented;
}

/// Operation: controlTransferOut
pub fn call_controlTransferOut(instance: *runtime.Instance, setup: dictionaries.USBControlTransferParameters, data: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = setup;
    _ = data;
    return error.NotImplemented;
}

/// Operation: controlTransferIn
pub fn call_controlTransferIn(instance: *runtime.Instance, setup: dictionaries.USBControlTransferParameters, length: u16) ImplError!*const anyopaque {
    _ = instance;
    _ = setup;
    _ = length;
    return error.NotImplemented;
}

/// Operation: forget
pub fn call_forget(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: reset
pub fn call_reset(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: transferOut
pub fn call_transferOut(instance: *runtime.Instance, endpointNumber: u8, data: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = endpointNumber;
    _ = data;
    return error.NotImplemented;
}

/// Operation: isochronousTransferIn
pub fn call_isochronousTransferIn(instance: *runtime.Instance, endpointNumber: u8, packetLengths: *const anyopaque) ImplError!*const anyopaque {
    _ = instance;
    _ = endpointNumber;
    _ = packetLengths;
    return error.NotImplemented;
}

/// Operation: clearHalt
pub fn call_clearHalt(instance: *runtime.Instance, direction: enums.USBDirection, endpointNumber: u8) ImplError!*const anyopaque {
    _ = instance;
    _ = direction;
    _ = endpointNumber;
    return error.NotImplemented;
}

/// Operation: claimInterface
pub fn call_claimInterface(instance: *runtime.Instance, interfaceNumber: u8) ImplError!*const anyopaque {
    _ = instance;
    _ = interfaceNumber;
    return error.NotImplemented;
}

/// Operation: selectAlternateInterface
pub fn call_selectAlternateInterface(instance: *runtime.Instance, interfaceNumber: u8, alternateSetting: u8) ImplError!*const anyopaque {
    _ = instance;
    _ = interfaceNumber;
    _ = alternateSetting;
    return error.NotImplemented;
}

/// Operation: isochronousTransferOut
pub fn call_isochronousTransferOut(instance: *runtime.Instance, endpointNumber: u8, data: typedefs.BufferSource, packetLengths: *const anyopaque) ImplError!*const anyopaque {
    _ = instance;
    _ = endpointNumber;
    _ = data;
    _ = packetLengths;
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: transferIn
pub fn call_transferIn(instance: *runtime.Instance, endpointNumber: u8, length: u32) ImplError!*const anyopaque {
    _ = instance;
    _ = endpointNumber;
    _ = length;
    return error.NotImplemented;
}

