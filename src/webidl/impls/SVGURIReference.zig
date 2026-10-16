//! Implementation for SVGURIReference interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SVGURIReference = interfaces.SVGURIReference;

pub const State = SVGURIReference.State;

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

/// SVG 2 4.7.4: reflect href and its deprecated xlink:href alternative.
/// The generated includer's [SameObject] getter caches this object.
pub fn get_href(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return interfaces.SVGAnimatedString.initWith(instance.ctx.allocator, instance.ctx, .{
        .reflected_element = instance,
        .reflected_attribute = "href",
        .deprecated_attribute_namespace = "http://www.w3.org/1999/xlink",
    });
}
