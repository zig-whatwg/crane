//! Implementation for DOMRect interface
//!
//! CSSOM View Module - DOMRect
//! Spec: https://drafts.csswg.org/geometry-1/#domrect
//!
//! Extends DOMRectReadOnly with mutable x, y, width, height properties.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const DOMRect = interfaces.DOMRect;
const DOMRectReadOnlyImpl = @import("DOMRectReadOnly.zig");

pub const State = DOMRect.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// Internal state - not currently used, dimensions stored in State.own
pub const InternalState = DOMRectReadOnlyImpl.InternalState;

/// Get state from instance
fn getState(instance: *runtime.Instance) *State {
    return instance.getState(State);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Initialize with dimensions
pub fn initWithDimensions(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
) !*runtime.Instance {
    const instance = try init(allocator, State, &DOMRect.vtable, ctx);
    errdefer deinit(instance);

    // Set state values
    const state = getState(instance);
    state.own.x = x;
    state.own.y = y;
    state.own.width = width;
    state.own.height = height;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Constructor implementation
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrect-domrect
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, x: webidl.Opt(f64), y: webidl.Opt(f64), width: webidl.Opt(f64), height: webidl.Opt(f64)) !*runtime.Instance {
    const x_val = if (x.was_passed) x.value else 0;
    const y_val = if (y.was_passed) y.value else 0;
    const width_val = if (width.was_passed) width.value else 0;
    const height_val = if (height.was_passed) height.value else 0;
    return initWithDimensions(allocator, ctx, x_val, y_val, width_val, height_val);
}

/// Getter for x
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrect-x
pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
    const state = getState(instance);
    return state.own.x;
}

/// Setter for x
pub fn set_x(instance: *runtime.Instance, value: f64) ImplError!void {
    const state = getState(instance);
    state.own.x = value;
}

/// Getter for y
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrect-y
pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
    const state = getState(instance);
    return state.own.y;
}

/// Setter for y
pub fn set_y(instance: *runtime.Instance, value: f64) ImplError!void {
    const state = getState(instance);
    state.own.y = value;
}

/// Getter for width
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrect-width
pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
    const state = getState(instance);
    return state.own.width;
}

/// Setter for width
pub fn set_width(instance: *runtime.Instance, value: f64) ImplError!void {
    const state = getState(instance);
    state.own.width = value;
}

/// Getter for height
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrect-height
pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
    const state = getState(instance);
    return state.own.height;
}

/// Setter for height
pub fn set_height(instance: *runtime.Instance, value: f64) ImplError!void {
    const state = getState(instance);
    state.own.height = value;
}

/// Operation: fromRect (static)
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrect-fromrect
/// Creates a new DOMRect from a DOMRectInit dictionary
pub fn call_static_fromRect(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMRectInit)) anyerror!*runtime.Instance {
    const ctx = instance.ctx;

    // Extract values from dictionary with defaults
    var x: f64 = 0;
    var y: f64 = 0;
    var width: f64 = 0;
    var height: f64 = 0;

    if (other.was_passed) {
        x = other.value.x orelse 0;
        y = other.value.y orelse 0;
        width = other.value.width orelse 0;
        height = other.value.height orelse 0;
    }

    return initWithDimensions(std.heap.page_allocator, ctx, x, y, width, height) catch return error.OutOfMemory;
}
