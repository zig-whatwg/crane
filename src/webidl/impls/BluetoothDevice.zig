//! Implementation for BluetoothDevice interface
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
const BluetoothDevice = interfaces.BluetoothDevice;

pub const State = BluetoothDevice.State;

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

/// Getter for id
pub fn get_id(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for gatt
pub fn get_gatt(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for watchingAdvertisements
pub fn get_watchingAdvertisements(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onadvertisementreceived
pub fn get_onadvertisementreceived(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ongattserverdisconnected
pub fn get_ongattserverdisconnected(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
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

/// Setter for onadvertisementreceived
pub fn set_onadvertisementreceived(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for ongattserverdisconnected
pub fn set_ongattserverdisconnected(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
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

/// Operation: watchAdvertisements
pub fn call_watchAdvertisements(instance: *runtime.Instance, options: dictionaries.WatchAdvertisementsOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: forget
pub fn call_forget(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

