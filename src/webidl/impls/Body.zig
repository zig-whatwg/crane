//! Implementation for Body interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const Body = interfaces.Body;

pub const State = Body.State;

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
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for body
pub fn get_body(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for bodyUsed
pub fn get_bodyUsed(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: blob
pub fn call_blob(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: formData
pub fn call_formData(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: text
pub fn call_text(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: json
pub fn call_json(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: bytes
pub fn call_bytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: arrayBuffer
pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}
