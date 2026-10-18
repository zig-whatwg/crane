//! Implementation for BarProp interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
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
/// HTML BarProp.visible steps 1-3, with the browser-majority result for
/// step 2: false without a live browsing context. The spec still says true;
/// whatwg/html#2579 proposed false in 2017 and closed without changing it.
/// wpt.fyi BarProp.window, stable 23b0b89b1a: Chrome/Safari 2/2, Firefox 0/2.
/// WebKit's BarProp::visible likewise returns false without a frame/page:
/// https://github.com/WebKit/WebKit/blob/main/Source/WebCore/page/BarProp.cpp
pub fn get_visible(instance: *runtime.Instance) anyerror!bool {
    const record = instance.ctx.getRealm() orelse return false;
    const global = record.global_object orelse return false;
    const navigables = @import("dom").browser_state.navigablesOf(instance.ctx) orelse return false;
    const browsing_context = navigables.ofWindow(global) orelse return false;
    if (browsing_context.is_closed) return false;
    return !browsing_context.getTop().is_popup;
}
