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
const DOMRect = interfaces.DOMRect;
const DOMRectReadOnlyImpl = @import("DOMRectReadOnly.zig");
const webidl = @import("webidl");

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
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrect-domrect
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, x: webidl.Opt(f64), y: webidl.Opt(f64), width: webidl.Opt(f64), height: webidl.Opt(f64)) !*runtime.Instance {
    // Extract values from Opt, using 0 as default per spec
    const x_val = if (x.wasPassed()) x.value else 0;
    const y_val = if (y.wasPassed()) y.value else 0;
    const width_val = if (width.wasPassed()) width.value else 0;
    const height_val = if (height.wasPassed()) height.value else 0;
    return initWithDimensions(allocator, ctx, x_val, y_val, width_val, height_val);
}

/// Getter for x
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrect-x
pub fn get_x(instance: *runtime.Instance) ImplError!f64 {
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
pub fn get_y(instance: *runtime.Instance) ImplError!f64 {
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
pub fn get_width(instance: *runtime.Instance) ImplError!f64 {
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
pub fn get_height(instance: *runtime.Instance) ImplError!f64 {
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
pub fn call_fromRect(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMRectInit)) ImplError!*runtime.Instance {
    const ctx = instance.ctx;

    // Extract values from dictionary with defaults (unwrap Opt)
    const x = if (other.wasPassed()) other.value.x orelse 0 else 0;
    const y = if (other.wasPassed()) other.value.y orelse 0 else 0;
    const width = if (other.wasPassed()) other.value.width orelse 0 else 0;
    const height = if (other.wasPassed()) other.value.height orelse 0 else 0;

    return initWithDimensions(std.heap.page_allocator, ctx, x, y, width, height) catch return error.OutOfMemory;
}
