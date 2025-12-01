//! Implementation for TextFormat interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const TextFormat = interfaces.TextFormat;

pub const State = TextFormat.State;

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

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, options: webidl.Opt(dictionaries.TextFormatInit)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &TextFormat.vtable, ctx);
    errdefer deinit(instance);

    _ = options;
    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for rangeStart
pub fn get_rangeStart(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for rangeEnd
pub fn get_rangeEnd(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for underlineStyle
pub fn get_underlineStyle(instance: *runtime.Instance) anyerror!enums.UnderlineStyle {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for underlineThickness
pub fn get_underlineThickness(instance: *runtime.Instance) anyerror!enums.UnderlineThickness {
    _ = instance;
    return error.NotImplemented;
}

