//! Auto-generated mixin: BluetoothDeviceEventHandlers
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const BluetoothDeviceEventHandlersImpl = @import("impls").BluetoothDeviceEventHandlers;

// Re-export types from impl
pub const impl = @import("impls").BluetoothDeviceEventHandlers;

pub fn get_onadvertisementreceived(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return BluetoothDeviceEventHandlersImpl.get_onadvertisementreceived(instance);
}

pub fn set_onadvertisementreceived(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return BluetoothDeviceEventHandlersImpl.set_onadvertisementreceived(instance, value);
}

pub fn get_ongattserverdisconnected(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return BluetoothDeviceEventHandlersImpl.get_ongattserverdisconnected(instance);
}

pub fn set_ongattserverdisconnected(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return BluetoothDeviceEventHandlersImpl.set_ongattserverdisconnected(instance, value);
}

