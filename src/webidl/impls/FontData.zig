//! Implementation for FontData interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const FontData = interfaces.FontData;

pub const State = FontData.State;

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

/// Getter for postscriptName
pub fn get_postscriptName(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fullName
pub fn get_fullName(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for family
pub fn get_family(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for style
pub fn get_style(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: blob
pub fn call_blob(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

