//! Implementation for SVGPreserveAspectRatio interface
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
const SVGPreserveAspectRatio = interfaces.SVGPreserveAspectRatio;

pub const State = SVGPreserveAspectRatio.State;

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

/// Getter for align
pub fn get_align(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for meetOrSlice
pub fn get_meetOrSlice(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for align
pub fn set_align(instance: *runtime.Instance, value: u16) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for meetOrSlice
pub fn set_meetOrSlice(instance: *runtime.Instance, value: u16) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

