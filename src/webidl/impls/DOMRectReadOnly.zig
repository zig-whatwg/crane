//! Implementation for DOMRectReadOnly interface
//!
//! Per the Geometry Interfaces Module Level 1:
//! https://drafts.fxtf.org/geometry/#domrectreadonly

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const DOMRectReadOnly = interfaces.DOMRectReadOnly;

pub const State = DOMRectReadOnly.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {};

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

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Constructor implementation
/// Creates a new DOMRectReadOnly with the given coordinates and dimensions
pub fn call_constructor(ctx: runtime.Context, x: webidl.Opt(f64), y: webidl.Opt(f64), width: webidl.Opt(f64), height: webidl.Opt(f64)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &DOMRectReadOnly.vtable, ctx);
    errdefer deinit(instance);

    // Get the actual values or defaults (0 per spec)
    const x_val = if (x.was_passed) x.value else 0.0;
    const y_val = if (y.was_passed) y.value else 0.0;
    const width_val = if (width.was_passed) width.value else 0.0;
    const height_val = if (height.was_passed) height.value else 0.0;

    // Store in state (FlattenedState has .own for own fields)
    const state = instance.getState(State);
    state.own.x = x_val;
    state.own.y = y_val;
    state.own.width = width_val;
    state.own.height = height_val;

    // Compute derived properties per spec
    // top = min(y, y + height)
    state.own.top = @min(y_val, y_val + height_val);
    // right = max(x, x + width)
    state.own.right = @max(x_val, x_val + width_val);
    // bottom = max(y, y + height)
    state.own.bottom = @max(y_val, y_val + height_val);
    // left = min(x, x + width)
    state.own.left = @min(x_val, x_val + width_val);

    return instance;
}

/// Getter for x
pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.x;
}

/// Getter for y
pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.y;
}

/// Getter for width
pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.width;
}

/// Getter for height
pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.height;
}

/// Getter for top
pub fn get_top(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.top;
}

/// Getter for right
pub fn get_right(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.right;
}

/// Getter for bottom
pub fn get_bottom(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.bottom;
}

/// Getter for left
pub fn get_left(instance: *runtime.Instance) anyerror!f64 {
    const state = instance.getState(State);
    return state.own.left;
}

/// Operation: fromRect
/// Creates a new DOMRectReadOnly from a DOMRectInit dictionary
pub fn call_static_fromRect(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMRectInit)) anyerror!*runtime.Instance {
    const ctx = instance.ctx;

    // Get values from dictionary or default to 0
    var x_val: f64 = 0.0;
    var y_val: f64 = 0.0;
    var width_val: f64 = 0.0;
    var height_val: f64 = 0.0;

    if (other.was_passed) {
        const rect_init = other.value;
        x_val = rect_init.x orelse 0.0;
        y_val = rect_init.y orelse 0.0;
        width_val = rect_init.width orelse 0.0;
        height_val = rect_init.height orelse 0.0;
    }

    // Create new instance using constructor
    return call_constructor(
        ctx,
        webidl.Opt(f64).passed(x_val),
        webidl.Opt(f64).passed(y_val),
        webidl.Opt(f64).passed(width_val),
        webidl.Opt(f64).passed(height_val),
    );
}

/// Operation: toJSON
/// Returns a plain object with the rect's properties.
/// Per the [Default] toJSON semantics, the returned object's prototype
/// should come from the method's realm (not the caller's realm).
///
/// The binding layer handles creating the object in the correct realm's context
/// Per WebIDL spec, [Default] toJSON returns an object with all exposed attributes.
/// The conversion layer will convert this struct to a JavaScript object using the
/// correct realm context for proper cross-realm support.
pub fn call_toJSON(instance: *runtime.Instance) anyerror!DOMRectReadOnly.DOMRectReadOnlyToJSON {
    const state = instance.getState(State);

    return .{
        .x = state.own.x,
        .y = state.own.y,
        .width = state.own.width,
        .height = state.own.height,
        .top = state.own.top,
        .right = state.own.right,
        .bottom = state.own.bottom,
        .left = state.own.left,
    };
}

pub fn call_fromRect(instance: *runtime.Instance, other: webidl.Opt(dictionaries.DOMRectInit)) anyerror!*runtime.Instance {
    return call_static_fromRect(instance, other);
}
