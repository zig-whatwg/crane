//! Implementation for NetworkInformation interface
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
const NetworkInformation = interfaces.NetworkInformation;

pub const State = NetworkInformation.State;

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

/// Getter for type
pub fn get_type(instance: *runtime.Instance) ImplError!enums.ConnectionType {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for effectiveType
pub fn get_effectiveType(instance: *runtime.Instance) ImplError!enums.EffectiveConnectionType {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for downlinkMax
pub fn get_downlinkMax(instance: *runtime.Instance) ImplError!typedefs.Megabit {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for downlink
pub fn get_downlink(instance: *runtime.Instance) ImplError!typedefs.Megabit {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for rtt
pub fn get_rtt(instance: *runtime.Instance) ImplError!typedefs.Millisecond {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for onchange
pub fn get_onchange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for saveData
pub fn get_saveData(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onchange
pub fn set_onchange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

