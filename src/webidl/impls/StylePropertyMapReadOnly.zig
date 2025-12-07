//! Implementation for StylePropertyMapReadOnly interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const StylePropertyMapReadOnly = interfaces.StylePropertyMapReadOnly;

pub const State = StylePropertyMapReadOnly.State;

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

/// Getter for size
pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: get
pub fn call_get(instance: *runtime.Instance, property: runtime.USVString) anyerror!*const anyopaque {
    _ = instance;
    _ = property;
    return error.NotImplemented;
}

/// Operation: getAll
pub fn call_getAll(instance: *runtime.Instance, property: runtime.USVString) anyerror!*const anyopaque {
    _ = instance;
    _ = property;
    return error.NotImplemented;
}

/// Operation: has
pub fn call_has(instance: *runtime.Instance, property: runtime.USVString) anyerror!bool {
    _ = instance;
    _ = property;
    return error.NotImplemented;
}

/// Operation: forEach
pub fn call_forEach(instance: *runtime.Instance, callback: runtime.JSValue) anyerror!void {
    _ = instance;
    _ = callback;
    return error.NotImplemented;
}

/// Entry type for pair iterable support
pub const IterableEntry = struct {
    name: runtime.USVString,
    value: []const *runtime.Instance, // sequence<CSSStyleValue>
};

/// Get entries for pair iterable support (used by V8 for iteration)
pub fn getEntriesInternal(instance: *runtime.Instance) ?[]const IterableEntry {
    _ = instance;
    return null; // TODO: Implement when StylePropertyMapReadOnly is fully implemented
}
