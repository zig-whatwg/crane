//! Implementation for EXT_disjoint_timer_query interface
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
const EXT_disjoint_timer_query = interfaces.EXT_disjoint_timer_query;

pub const State = EXT_disjoint_timer_query.State;

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

/// Operation: queryCounterEXT
pub fn call_queryCounterEXT(instance: *runtime.Instance, query: interfaces.WebGLTimerQueryEXT, target: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = query;
    _ = target;
    return error.NotImplemented;
}

/// Operation: createQueryEXT
pub fn call_createQueryEXT(instance: *runtime.Instance) ImplError!interfaces.WebGLTimerQueryEXT {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: endQueryEXT
pub fn call_endQueryEXT(instance: *runtime.Instance, target: typedefs.GLenum) ImplError!void {
    _ = instance;
    _ = target;
    return error.NotImplemented;
}

/// Operation: isQueryEXT
pub fn call_isQueryEXT(instance: *runtime.Instance, query: interfaces.WebGLTimerQueryEXT) ImplError!bool {
    _ = instance;
    _ = query;
    return error.NotImplemented;
}

/// Operation: beginQueryEXT
pub fn call_beginQueryEXT(instance: *runtime.Instance, target: typedefs.GLenum, query: interfaces.WebGLTimerQueryEXT) ImplError!void {
    _ = instance;
    _ = target;
    _ = query;
    return error.NotImplemented;
}

/// Operation: getQueryObjectEXT
pub fn call_getQueryObjectEXT(instance: *runtime.Instance, query: interfaces.WebGLTimerQueryEXT, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = query;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: getQueryEXT
pub fn call_getQueryEXT(instance: *runtime.Instance, target: typedefs.GLenum, pname: typedefs.GLenum) ImplError!*const anyopaque {
    _ = instance;
    _ = target;
    _ = pname;
    return error.NotImplemented;
}

/// Operation: deleteQueryEXT
pub fn call_deleteQueryEXT(instance: *runtime.Instance, query: interfaces.WebGLTimerQueryEXT) ImplError!void {
    _ = instance;
    _ = query;
    return error.NotImplemented;
}

