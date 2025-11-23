//! Implementation for USBEndpoint interface
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
const USBEndpoint = interfaces.USBEndpoint;

pub const State = USBEndpoint.State;

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

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, alternate: interfaces.USBAlternateInterface, endpointNumber: u8, direction: enums.USBDirection) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &USBEndpoint.vtable, ctx);
    errdefer deinit(instance);

    _ = alternate;
    _ = endpointNumber;
    _ = direction;
    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for endpointNumber
pub fn get_endpointNumber(instance: *runtime.Instance) ImplError!u8 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for direction
pub fn get_direction(instance: *runtime.Instance) ImplError!enums.USBDirection {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) ImplError!enums.USBEndpointType {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for packetSize
pub fn get_packetSize(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

