//! Implementation for XRMesh interface
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
const XRMesh = interfaces.XRMesh;

pub const State = XRMesh.State;

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

/// Getter for meshSpace
pub fn get_meshSpace(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for vertices
pub fn get_vertices(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for indices
pub fn get_indices(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lastChangedTime
pub fn get_lastChangedTime(instance: *runtime.Instance) ImplError!typedefs.DOMHighResTimeStamp {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for semanticLabel
pub fn get_semanticLabel(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

