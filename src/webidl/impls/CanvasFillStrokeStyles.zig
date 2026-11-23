//! Implementation for CanvasFillStrokeStyles interface
//!
//! HTML 4.12.5.1.10: a 2D context's fill and stroke styles - the drawing
//! state of whichever context includes this mixin (CanvasRenderingContext2D,
//! OffscreenCanvasRenderingContext2D), reached through dom.canvas_2d.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasFillStrokeStyles = interfaces.CanvasFillStrokeStyles;
const engine = @import("engine");
const dom = @import("dom");

pub const State = CanvasFillStrokeStyles.State;

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

/// The getter steps of fillStyle and strokeStyle: "If this's fill (stroke)
/// style is a CSS color, then return the serialization of that color with
/// HTML-compatible serialization requested. Return this's fill (stroke)
/// style."
fn styleValue(instance: *runtime.Instance, style: dom.canvas_2d.Style) !runtime.JSValue {
    switch (style) {
        .color => |color| {
            const text = try dom.canvas_2d.serializeColor(instance.ctx.allocator, color);
            // The binding takes the string.
            return .{ .string = .{ .data = text, .owned = true } };
        },
    }
}

/// The setter steps of fillStyle and strokeStyle, given the value converted
/// to (DOMString or CanvasGradient or CanvasPattern): a string is parsed as
/// a CSS color - "If parsedValue is failure, then return" - and set. A
/// CanvasGradient or CanvasPattern would be set as it is; none can exist
/// yet (their factories are not implemented), so every value converts to
/// its string (WebIDL union conversion step 11: ToString, which may throw).
fn setStyle(instance: *runtime.Instance, slot: *dom.canvas_2d.Style, value: runtime.JSValue) !void {
    const realm = engine.currentRealm() orelse instance.ctx;
    const allocator = instance.ctx.allocator;
    const text = try engine.convertToDOMString(realm, value, allocator);
    defer allocator.free(text);
    // 1.1-1.2. Parse the value (with the canvas element as context; see
    //          dom.canvas_2d.parseColor for currentcolor).
    const parsed = dom.canvas_2d.parseColor(text) orelse return; // 1.3.
    // 1.4.
    slot.* = .{ .color = parsed };
}

/// Getter for strokeStyle (HTML 4.12.5.1.10).
pub fn get_strokeStyle(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = try stateOf(instance);
    return styleValue(instance, state.drawing.stroke_style);
}

/// Getter for fillStyle (HTML 4.12.5.1.10).
pub fn get_fillStyle(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = try stateOf(instance);
    return styleValue(instance, state.drawing.fill_style);
}

/// Setter for strokeStyle (HTML 4.12.5.1.10).
pub fn set_strokeStyle(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    const state = try stateOf(instance);
    try setStyle(instance, &state.drawing.stroke_style, value);
}

/// Setter for fillStyle (HTML 4.12.5.1.10).
pub fn set_fillStyle(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    const state = try stateOf(instance);
    try setStyle(instance, &state.drawing.fill_style, value);
}

/// Operation: createLinearGradient
pub fn call_createLinearGradient(instance: *runtime.Instance, x0: f64, y0: f64, x1: f64, y1: f64) anyerror!*runtime.Instance {
    _ = instance;
    _ = x0;
    _ = y0;
    _ = x1;
    _ = y1;
    return error.NotImplemented;
}

/// Operation: createPattern
pub fn call_createPattern(instance: *runtime.Instance, image: typedefs.CanvasImageSource, repetition: runtime.DOMString) anyerror!?*runtime.Instance {
    _ = instance;
    _ = image;
    _ = repetition;
    return null;
}

/// Operation: createConicGradient
pub fn call_createConicGradient(instance: *runtime.Instance, startAngle: f64, x: f64, y: f64) anyerror!*runtime.Instance {
    _ = instance;
    _ = startAngle;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: createRadialGradient
pub fn call_createRadialGradient(instance: *runtime.Instance, x0: f64, y0: f64, r0: f64, x1: f64, y1: f64, r1: f64) anyerror!*runtime.Instance {
    _ = instance;
    _ = x0;
    _ = y0;
    _ = r0;
    _ = x1;
    _ = y1;
    _ = r1;
    return error.NotImplemented;
}
