//! Auto-generated mixin: BluetoothDeviceEventHandlers
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BluetoothDeviceEventHandlersImpl = @import("impls").BluetoothDeviceEventHandlers;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventHandler = @import("typedefs").EventHandler;

pub const impl = @import("impls").BluetoothDeviceEventHandlers;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "BluetoothDeviceEventHandlers")) {
        if (comptime @hasDecl(impls.BluetoothDeviceEventHandlers, "installHooks")) impls.BluetoothDeviceEventHandlers.installHooks();
    }
}

pub fn get_onadvertisementreceived(instance: *runtime.Instance) anyerror!EventHandler {
    return try BluetoothDeviceEventHandlersImpl.get_onadvertisementreceived(instance);
}

pub fn set_onadvertisementreceived(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    try BluetoothDeviceEventHandlersImpl.set_onadvertisementreceived(instance, value);
}

pub fn get_ongattserverdisconnected(instance: *runtime.Instance) anyerror!EventHandler {
    return try BluetoothDeviceEventHandlersImpl.get_ongattserverdisconnected(instance);
}

pub fn set_ongattserverdisconnected(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    try BluetoothDeviceEventHandlersImpl.set_ongattserverdisconnected(instance, value);
}
