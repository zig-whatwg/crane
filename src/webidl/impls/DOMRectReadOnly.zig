//! Implementation for DOMRectReadOnly interface
//!
//! Per the Geometry Interfaces Module Level 1:
//! https://drafts.fxtf.org/geometry/#domrectreadonly
//!
//! A rectangle's x coordinate, y coordinate, width dimension and height
//! dimension are this interface's internal member variables, kept in its
//! State; top, right, bottom and left are computed from them on every get
//! (Geometry 3). DOMRect (which inherits them) reads them through this
//! interface's getters and sets them through dom.geometry_storage, the step
//! installed here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const geometry = @import("css").geometry;
const geometry_storage = @import("dom").geometry_storage;
const DOMRectReadOnly = interfaces.DOMRectReadOnly;

pub const State = DOMRectReadOnly.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
pub const InternalState = struct {};

/// The hooks this type owns (src/dom), installed once, at process start.
pub fn installHooks() void {
    geometry_storage.installRect(&setRect);
}

/// Initialize instance (creates the instance): the rectangle (0, 0, 0, 0)
/// until its maker sets one. DOMRect's state is made here too, through this
/// interface's initWithState.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    setRect(instance, .{});
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// dom.geometry_storage: set the rectangle's variables.
fn setRect(instance: *runtime.Instance, rect: geometry.Rect) void {
    const state = instance.getState(State);
    state.own.x = rect.x;
    state.own.y = rect.y;
    state.own.width = rect.width;
    state.own.height = rect.height;
}

fn rectOf(instance: *runtime.Instance) geometry.Rect {
    const state = instance.getState(State);
    return .{ .x = state.own.x, .y = state.own.y, .width = state.own.width, .height = state.own.height };
}

/// Geometry 3, the DOMRectReadOnly(x, y, width, height) constructor:
/// 1. Let rect be a new DOMRectReadOnly object.
/// 2. Set rect's variables x coordinate to x, y coordinate to y, width
///    dimension to width and height dimension to height.
/// 3. Return rect.
pub fn call_constructor(ctx: runtime.Context, x: webidl.Opt(f64), y: webidl.Opt(f64), width: webidl.Opt(f64), height: webidl.Opt(f64)) !*runtime.Instance {
    // 1.
    const instance = try init(ctx.allocator, State, &DOMRectReadOnly.vtable, ctx);
    // 2. (Every argument defaults to 0.)
    setRect(instance, .{
        .x = if (x.was_passed) x.value else 0,
        .y = if (y.was_passed) y.value else 0,
        .width = if (width.was_passed) width.value else 0,
        .height = if (height.was_passed) height.value else 0,
    });
    // 3.
    return instance;
}

/// Getter for x: the x coordinate.
pub fn get_x(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.x;
}

/// Getter for y: the y coordinate.
pub fn get_y(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.y;
}

/// Getter for width: the width dimension.
pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.width;
}

/// Getter for height: the height dimension.
pub fn get_height(instance: *runtime.Instance) anyerror!f64 {
    return instance.getState(State).own.height;
}

/// Getter for top: min(y coordinate, y coordinate + height dimension).
pub fn get_top(instance: *runtime.Instance) anyerror!f64 {
    return rectOf(instance).top();
}

/// Getter for right: max(x coordinate, x coordinate + width dimension).
pub fn get_right(instance: *runtime.Instance) anyerror!f64 {
    return rectOf(instance).right();
}

/// Getter for bottom: max(y coordinate, y coordinate + height dimension).
pub fn get_bottom(instance: *runtime.Instance) anyerror!f64 {
    return rectOf(instance).bottom();
}

/// Getter for left: min(x coordinate, x coordinate + width dimension).
pub fn get_left(instance: *runtime.Instance) anyerror!f64 {
    return rectOf(instance).left();
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
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.DOMRectReadOnly.DOMRectReadOnlyToJSON {
    const rect = rectOf(instance);
    return .{
        .x = rect.x,
        .y = rect.y,
        .width = rect.width,
        .height = rect.height,
        .top = rect.top(),
        .right = rect.right(),
        .bottom = rect.bottom(),
        .left = rect.left(),
    };
}

// ============================================================================
// Serializable objects (HTML 2.7.1; Geometry 7: DOMRectReadOnly is
// [Serializable])
// ============================================================================

/// Geometry 7, the serialization steps for DOMRectReadOnly and DOMRect,
/// given `value` and `serialized`:
/// 1. Set serialized.[[X]] to value's x coordinate.
/// 2. Set serialized.[[Y]] to value's y coordinate.
/// 3. Set serialized.[[Width]] to value's width dimension.
/// 4. Set serialized.[[Height]] to value's height dimension.
pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) !void {
    const rect = rectOf(value);
    try serialized.writeDouble(rect.x);
    try serialized.writeDouble(rect.y);
    try serialized.writeDouble(rect.width);
    try serialized.writeDouble(rect.height);
}

/// Geometry 7, the deserialization steps for DOMRectReadOnly and DOMRect,
/// given `serialized` and `value`:
/// 1. Set value's x coordinate to serialized.[[X]].
/// 2. Set value's y coordinate to serialized.[[Y]].
/// 3. Set value's width dimension to serialized.[[Width]].
/// 4. Set value's height dimension to serialized.[[Height]].
pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) !void {
    _ = target_realm;
    var rect: geometry.Rect = undefined;
    rect.x = try serialized.readDouble();
    rect.y = try serialized.readDouble();
    rect.width = try serialized.readDouble();
    rect.height = try serialized.readDouble();
    setRect(value, rect);
}
