//! Implementation for DOMRectReadOnly interface
//!
//! CSSOM View Module - DOMRectReadOnly
//! Spec: https://drafts.csswg.org/geometry-1/#domrectreadonly
//!
//! Represents a rectangle with x, y, width, height coordinates.
//! The read-only version provides computed properties (top, right, bottom, left).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const DOMRectReadOnly = interfaces.DOMRectReadOnly;

pub const State = DOMRectReadOnly.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
};

/// Internal state - not currently used, dimensions stored in State.own
pub const InternalState = struct {};

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
    const instance = try init(allocator, State, &DOMRectReadOnly.vtable, ctx);
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
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrectreadonly-domrectreadonly
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, x: f64, y: f64, width: f64, height: f64) !*runtime.Instance {
    return initWithDimensions(allocator, ctx, x, y, width, height);
}

/// Getter for x
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrectreadonly-x
pub fn get_x(instance: *runtime.Instance) ImplError!f64 {
    const state = getState(instance);
    return state.own.x;
}

/// Getter for y
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrectreadonly-y
pub fn get_y(instance: *runtime.Instance) ImplError!f64 {
    const state = getState(instance);
    return state.own.y;
}

/// Getter for width
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrectreadonly-width
pub fn get_width(instance: *runtime.Instance) ImplError!f64 {
    const state = getState(instance);
    return state.own.width;
}

/// Getter for height
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrectreadonly-height
pub fn get_height(instance: *runtime.Instance) ImplError!f64 {
    const state = getState(instance);
    return state.own.height;
}

/// Getter for top
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrectreadonly-top
/// Returns min(y, y + height)
pub fn get_top(instance: *runtime.Instance) ImplError!f64 {
    const state = getState(instance);
    return @min(state.own.y, state.own.y + state.own.height);
}

/// Getter for right
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrectreadonly-right
/// Returns max(x, x + width)
pub fn get_right(instance: *runtime.Instance) ImplError!f64 {
    const state = getState(instance);
    return @max(state.own.x, state.own.x + state.own.width);
}

/// Getter for bottom
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrectreadonly-bottom
/// Returns max(y, y + height)
pub fn get_bottom(instance: *runtime.Instance) ImplError!f64 {
    const state = getState(instance);
    return @max(state.own.y, state.own.y + state.own.height);
}

/// Getter for left
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrectreadonly-left
/// Returns min(x, x + width)
pub fn get_left(instance: *runtime.Instance) ImplError!f64 {
    const state = getState(instance);
    return @min(state.own.x, state.own.x + state.own.width);
}

/// Operation: fromRect (static)
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrectreadonly-fromrect
/// Creates a new DOMRectReadOnly from a DOMRectInit dictionary
pub fn call_fromRect(instance: *runtime.Instance, other: dictionaries.DOMRectInit) ImplError!*runtime.Instance {
    // Get allocator from context (arena allocator)
    const ctx = instance.ctx;

    // Extract values from dictionary with defaults
    const x = other.x orelse 0;
    const y = other.y orelse 0;
    const width = other.width orelse 0;
    const height = other.height orelse 0;

    return initWithDimensions(std.heap.page_allocator, ctx, x, y, width, height) catch return error.OutOfMemory;
}

/// Operation: toJSON
/// Spec: https://drafts.csswg.org/geometry-1/#dom-domrectreadonly-tojson
/// Returns an object with x, y, width, height, top, right, bottom, left
pub fn call_toJSON(instance: *runtime.Instance) ImplError!*const anyopaque {
    // TODO: Return a proper JSON object representation
    // For now, return a pointer to the instance itself
    // This needs proper serialization support
    _ = instance;
    return error.NotImplemented;
}
