//! Implementation for USBDevice interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const USBDevice = @import("interfaces").USBDevice;

pub const State = USBDevice.State;

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

/// Getter for usbVersionMajor
pub fn get_usbVersionMajor(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for usbVersionMinor
pub fn get_usbVersionMinor(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for usbVersionSubminor
pub fn get_usbVersionSubminor(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for deviceClass
pub fn get_deviceClass(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for deviceSubclass
pub fn get_deviceSubclass(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for deviceProtocol
pub fn get_deviceProtocol(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for vendorId
pub fn get_vendorId(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for productId
pub fn get_productId(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for deviceVersionMajor
pub fn get_deviceVersionMajor(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for deviceVersionMinor
pub fn get_deviceVersionMinor(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for deviceVersionSubminor
pub fn get_deviceVersionSubminor(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for manufacturerName
pub fn get_manufacturerName(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for productName
pub fn get_productName(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for serialNumber
pub fn get_serialNumber(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for configuration
pub fn get_configuration(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for configurations
pub fn get_configurations(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for opened
pub fn get_opened(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: open
pub fn call_open(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: forget
pub fn call_forget(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: selectConfiguration
pub fn call_selectConfiguration(instance: *runtime.Instance, configurationValue: u8) ImplError!anyopaque {
    _ = instance;
    _ = configurationValue;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: claimInterface
pub fn call_claimInterface(instance: *runtime.Instance, interfaceNumber: u8) ImplError!anyopaque {
    _ = instance;
    _ = interfaceNumber;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: releaseInterface
pub fn call_releaseInterface(instance: *runtime.Instance, interfaceNumber: u8) ImplError!anyopaque {
    _ = instance;
    _ = interfaceNumber;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: selectAlternateInterface
pub fn call_selectAlternateInterface(instance: *runtime.Instance, interfaceNumber: u8, alternateSetting: u8) ImplError!anyopaque {
    _ = instance;
    _ = interfaceNumber;
    _ = alternateSetting;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: controlTransferIn
pub fn call_controlTransferIn(instance: *runtime.Instance, setup: anyopaque, length: u16) ImplError!anyopaque {
    _ = instance;
    _ = setup;
    _ = length;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: controlTransferOut
pub fn call_controlTransferOut(instance: *runtime.Instance, setup: anyopaque, data: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = setup;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: clearHalt
pub fn call_clearHalt(instance: *runtime.Instance, direction: anyopaque, endpointNumber: u8) ImplError!anyopaque {
    _ = instance;
    _ = direction;
    _ = endpointNumber;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: transferIn
pub fn call_transferIn(instance: *runtime.Instance, endpointNumber: u8, length: u32) ImplError!anyopaque {
    _ = instance;
    _ = endpointNumber;
    _ = length;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: transferOut
pub fn call_transferOut(instance: *runtime.Instance, endpointNumber: u8, data: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = endpointNumber;
    _ = data;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isochronousTransferIn
pub fn call_isochronousTransferIn(instance: *runtime.Instance, endpointNumber: u8, packetLengths: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = endpointNumber;
    _ = packetLengths;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isochronousTransferOut
pub fn call_isochronousTransferOut(instance: *runtime.Instance, endpointNumber: u8, data: anyopaque, packetLengths: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = endpointNumber;
    _ = data;
    _ = packetLengths;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: reset
pub fn call_reset(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

