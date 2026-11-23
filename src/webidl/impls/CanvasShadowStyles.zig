//! Implementation for CanvasShadowStyles interface
//!
//! HTML 4.12.5.1.19: the shadow offsets, blur and color of whichever 2D
//! context includes this mixin, in its drawing state. (Shadows are not
//! painted yet: dom.canvas_2d.)

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const dom = @import("dom");
const CanvasShadowStyles = interfaces.CanvasShadowStyles;

pub const State = CanvasShadowStyles.State;

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

/// The 2D context's state; an InvalidStateError for one whose state is gone
/// (or an includer that keeps none - PaintRenderingContext2D, which no paint
/// worklet makes yet).
fn stateOf(instance: *runtime.Instance) !*dom.canvas_2d.Context2D {
    return dom.canvas_2d.stateOf(instance) orelse error.InvalidStateError;
}

/// Getter for shadowOffsetX: "On getting, they must return their current
/// value" (initially 0).
pub fn get_shadowOffsetX(instance: *runtime.Instance) anyerror!f64 {
    return (try stateOf(instance)).drawing.shadow_offset_x;
}

/// Getter for shadowOffsetY: "On getting, they must return their current
/// value" (initially 0).
pub fn get_shadowOffsetY(instance: *runtime.Instance) anyerror!f64 {
    return (try stateOf(instance)).drawing.shadow_offset_y;
}

/// Getter for shadowBlur: "On getting, the attribute must return its
/// current value" (initially 0).
pub fn get_shadowBlur(instance: *runtime.Instance) anyerror!f64 {
    return (try stateOf(instance)).drawing.shadow_blur;
}

/// Getter for shadowColor: "return the serialization of this's shadow
/// color with HTML-compatible serialization requested" (initially
/// transparent black).
pub fn get_shadowColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = try stateOf(instance);
    const text = try dom.canvas_2d.serializeColor(instance.ctx.allocator, state.drawing.shadow_color);
    defer instance.ctx.allocator.free(text);
    return runtime.DOMString.initDupe(instance.ctx.allocator, text);
}

/// Setter for shadowOffsetX: "the attribute being set must be set to the
/// new value, except if the value is infinite or NaN, in which case the new
/// value must be ignored."
pub fn set_shadowOffsetX(instance: *runtime.Instance, value: f64) anyerror!void {
    const state = try stateOf(instance);
    if (!std.math.isFinite(value)) return;
    state.drawing.shadow_offset_x = value;
}

/// Setter for shadowOffsetY: "the attribute being set must be set to the
/// new value, except if the value is infinite or NaN, in which case the new
/// value must be ignored."
pub fn set_shadowOffsetY(instance: *runtime.Instance, value: f64) anyerror!void {
    const state = try stateOf(instance);
    if (!std.math.isFinite(value)) return;
    state.drawing.shadow_offset_y = value;
}

/// Setter for shadowBlur: "the attribute must be set to the new value,
/// except if the value is negative, infinite or NaN, in which case the new
/// value must be ignored."
pub fn set_shadowBlur(instance: *runtime.Instance, value: f64) anyerror!void {
    const state = try stateOf(instance);
    if (!std.math.isFinite(value) or value < 0) return;
    state.drawing.shadow_blur = value;
}

/// Setter for shadowColor: "1. Let context be this's canvas attribute's
/// value, if that is an element; otherwise null. 2. Let parsedValue be the
/// result of parsing the given value with context if non-null. 3. If
/// parsedValue is failure, then return. 4. Set this's shadow color to
/// parsedValue." (Parsing with the element: see dom.canvas_2d.parseColor
/// for currentcolor.)
pub fn set_shadowColor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const state = try stateOf(instance);
    const parsed = dom.canvas_2d.parseColor(value.asSlice()) orelse return; // 2-3.
    state.drawing.shadow_color = parsed; // 4.
}
