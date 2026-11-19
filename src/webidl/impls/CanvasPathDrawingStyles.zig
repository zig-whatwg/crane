//! Implementation for CanvasPathDrawingStyles interface
//!
//! HTML 4.12.5.1.5: the line styles of whichever 2D context includes this
//! mixin (dom.canvas_2d). The dash list and its offset are kept; lineWidth,
//! lineCap, lineJoin and miterLimit are not implemented yet, so a stroke
//! uses their initial values (1, butt, miter, 10).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasPathDrawingStyles = interfaces.CanvasPathDrawingStyles;
const engine = @import("engine");
const dom = @import("dom");

pub const State = CanvasPathDrawingStyles.State;

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

/// Getter for lineWidth
pub fn get_lineWidth(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lineCap
pub fn get_lineCap(instance: *runtime.Instance) anyerror!enums.CanvasLineCap {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lineJoin
pub fn get_lineJoin(instance: *runtime.Instance) anyerror!enums.CanvasLineJoin {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for miterLimit
pub fn get_miterLimit(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// The 2D context's state; an InvalidStateError for one whose state is gone
/// (or an includer that keeps none - PaintRenderingContext2D, which no paint
/// worklet makes yet).
fn stateOf(instance: *runtime.Instance) !*dom.canvas_2d.Context2D {
    return dom.canvas_2d.stateOf(instance) orelse error.InvalidStateError;
}

/// Getter for lineDashOffset: "On getting, it must return the current
/// value" (initially 0).
pub fn get_lineDashOffset(instance: *runtime.Instance) anyerror!f64 {
    const state = try stateOf(instance);
    return state.line_dash_offset;
}

/// Setter for lineWidth
pub fn set_lineWidth(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for lineCap
pub fn set_lineCap(instance: *runtime.Instance, value: enums.CanvasLineCap) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for lineJoin
pub fn set_lineJoin(instance: *runtime.Instance, value: enums.CanvasLineJoin) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for miterLimit
pub fn set_miterLimit(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for lineDashOffset: "On setting, infinite and NaN values must be
/// ignored, leaving the value unchanged; other values must change the
/// current value to the new value."
pub fn set_lineDashOffset(instance: *runtime.Instance, value: f64) anyerror!void {
    const state = try stateOf(instance);
    if (!std.math.isFinite(value)) return;
    state.line_dash_offset = value;
}

/// Operation: getLineDash
/// Spec: https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-getlinedash
/// "return a sequence whose values are the values of this's dash list, in
/// the same order" - a new Array each call, in the current realm (WebIDL
/// converts a result there). Its items are data properties
/// (CreateDataProperty), so an accessor on Array.prototype is never reached.
pub fn call_getLineDash(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = try stateOf(instance);
    const dash = state.line_dash;
    const allocator = instance.ctx.allocator;
    const values = try allocator.alloc(runtime.JSValue, dash.len);
    defer allocator.free(values);
    for (dash, values) |segment, *value| value.* = runtime.JSValue.fromNumber(segment);
    const realm = engine.currentRealm() orelse instance.ctx;
    // A new value made for the call: the binding takes it.
    return (try engine.createSequenceOfValues(realm, values)).take();
}

/// The IDL value of a `sequence<unrestricted double>` argument being
/// converted, item by item (WebIDL 3.2.21 "create a sequence from an
/// iterable", each item converted to unrestricted double).
const DoubleSequence = struct {
    realm: runtime.Context,
    allocator: std.mem.Allocator,
    items: std.ArrayListUnmanaged(f64) = .empty,

    fn each(data: ?*anyopaque, item: runtime.JSValue) engine.Error!void {
        const self: *DoubleSequence = @ptrCast(@alignCast(data.?));
        // ToNumber: what a valueOf throws is pending, and propagates.
        const number = try engine.convertToUnrestrictedDouble(self.realm, item);
        self.items.append(self.allocator, number) catch return error.OutOfMemory;
    }
};

/// Operation: setLineDash
/// Spec: https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-setlinedash
///
/// `segments` is a `sequence<unrestricted double>`, which arrives unconverted:
/// WebIDL converts the whole of it - any iterable object, anything else a
/// TypeError, each item by ToNumber - before the method's steps run.
pub fn call_setLineDash(instance: *runtime.Instance, segments: runtime.JSValue) anyerror!void {
    const state = try stateOf(instance);
    const allocator = state.allocator;

    var sequence = DoubleSequence{ .realm = instance.ctx, .allocator = allocator };
    defer sequence.items.deinit(allocator);
    // WebIDL 3.2.21 steps 1-3: not an object, or no @@iterator, is a TypeError.
    if (!try engine.iterate(instance.ctx, segments, DoubleSequence.each, &sequence)) return error.TypeError;
    const values = sequence.items.items;

    // 1. If any value in segments is not finite (e.g. an Infinity or a NaN
    // value), or if any value is negative (less than zero), then return
    // (without throwing an exception).
    for (values) |value| {
        if (!std.math.isFinite(value) or value < 0) return;
    }

    // 2. If the number of elements in segments is odd, then let segments be
    // the concatenation of two copies of segments.
    const count = if (values.len % 2 != 0) values.len * 2 else values.len;
    const dash = try allocator.alloc(f64, count);
    @memcpy(dash[0..values.len], values);
    if (count != values.len) @memcpy(dash[values.len..], values);

    // 3. Set this's dash list to segments.
    if (state.line_dash.len > 0) allocator.free(state.line_dash);
    state.line_dash = dash;
}
