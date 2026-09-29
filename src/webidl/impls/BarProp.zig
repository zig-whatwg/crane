//! Implementation for BarProp interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const html_core = @import("html_core");
const BarProp = interfaces.BarProp;

pub const State = BarProp.State;

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

/// Getter for visible
/// HTML §7.2.2.2: "1. Let browsingContext be this's relevant global object's
/// browsing context. 2. If browsingContext is null, then return true. 3.
/// Return the negation of browsingContext's top-level browsing context's is
/// popup."
pub fn get_visible(instance: *runtime.Instance) anyerror!bool {
    const record = instance.ctx.getRealm() orelse return true;
    const global = record.global_object orelse return true;
    const browsing_context = html_core.BrowsingContext.ofWindow(@ptrCast(global)) orelse return true;
    return !browsing_context.getTop().is_popup;
}
