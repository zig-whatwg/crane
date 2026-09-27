//! Implementation for CanvasRenderingContext2D interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const CanvasRenderingContext2D = interfaces.CanvasRenderingContext2D;
const engine = @import("engine");

// Use shared InstanceRegistry utility for internal state management
const utils = @import("webidl").utils;

pub const State = CanvasRenderingContext2D.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for CanvasRenderingContext2D
/// Contains private data for canvas rendering:
/// - line_dash: Current line dash pattern (sequence of f64)
/// - line_dash_offset: Offset for line dash pattern
pub const InternalState = struct {
    /// Current line dash pattern - stored as owned slice
    line_dash: []f64 = &[_]f64{},
    /// Offset for line dash pattern
    line_dash_offset: f64 = 0,
    /// Allocator used for this state
    allocator: std.mem.Allocator = undefined,

    pub fn deinit(self: *InternalState) void {
        if (self.line_dash.len > 0) {
            self.allocator.free(self.line_dash);
            self.line_dash = &[_]f64{};
        }
    }
};

const Registry = utils.InstanceRegistry(InternalState);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

fn getOrCreateInternal(instance: *runtime.Instance) !*InternalState {
    if (Registry.get(instance)) |internal| {
        return internal;
    }
    // Create new internal state
    const allocator = instance.ctx.allocator;
    const internal = try allocator.create(InternalState);
    internal.* = .{
        .allocator = allocator,
    };
    try Registry.set(instance, internal);
    return internal;
}

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
    // Clean up internal state if it exists
    if (Registry.get(instance)) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    Registry.remove(instance);
}

/// Getter for canvas
pub fn get_canvas(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for strokeStyle
pub fn get_strokeStyle(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fillStyle
pub fn get_fillStyle(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
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

/// Getter for lineDashOffset
pub fn get_lineDashOffset(instance: *runtime.Instance) anyerror!f64 {
    const internal = getInternal(instance) orelse return 0;
    return internal.line_dash_offset;
}

/// Setter for strokeStyle
pub fn set_strokeStyle(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for fillStyle
pub fn set_fillStyle(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
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

/// Setter for lineDashOffset
pub fn set_lineDashOffset(instance: *runtime.Instance, value: f64) anyerror!void {
    const internal = try getOrCreateInternal(instance);
    internal.line_dash_offset = value;
}

/// Operation: rect
pub fn call_rect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    return error.NotImplemented;
}

/// Operation: getLineDash
/// Spec: https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-getlinedash
/// "return a sequence whose values are the values of this's dash list, in
/// the same order" - a new Array each call, in the current realm (WebIDL
/// converts a result there). Its items are data properties
/// (CreateDataProperty), so an accessor on Array.prototype is never reached:
/// the old "known V8 limitation" here was Set used where the conversion
/// defines.
pub fn call_getLineDash(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const dash: []const f64 = if (getInternal(instance)) |internal| internal.line_dash else &.{};
    const allocator = instance.ctx.allocator;
    const values = try allocator.alloc(runtime.JSValue, dash.len);
    defer allocator.free(values);
    for (dash, values) |segment, *value| value.* = runtime.JSValue.fromNumber(segment);
    const realm = engine.currentRealm() orelse instance.ctx;
    // A new value made for the call: the binding takes it.
    return (try engine.createSequenceOfValues(realm, values)).take();
}

/// Operation: ellipse
pub fn call_ellipse(instance: *runtime.Instance, x: f64, y: f64, radiusX: f64, radiusY: f64, rotation: f64, startAngle: f64, endAngle: f64, counterclockwise: webidl.Opt(bool)) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = radiusX;
    _ = radiusY;
    _ = rotation;
    _ = startAngle;
    _ = endAngle;
    _ = counterclockwise;
    return error.NotImplemented;
}

/// Operation: createConicGradient
pub fn call_createConicGradient(instance: *runtime.Instance, startAngle: f64, x: f64, y: f64) anyerror!*runtime.Instance {
    _ = instance;
    _ = startAngle;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: arc
pub fn call_arc(instance: *runtime.Instance, x: f64, y: f64, radius: f64, startAngle: f64, endAngle: f64, counterclockwise: webidl.Opt(bool)) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = radius;
    _ = startAngle;
    _ = endAngle;
    _ = counterclockwise;
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

/// Operation: closePath
pub fn call_closePath(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: roundRect
pub fn call_roundRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64, radii: webidl.Opt(runtime.JSValue)) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    _ = radii;
    return error.NotImplemented;
}

/// Operation: createPattern
pub fn call_createPattern(instance: *runtime.Instance, image: typedefs.CanvasImageSource, repetition: runtime.DOMString) anyerror!?*runtime.Instance {
    _ = instance;
    _ = image;
    _ = repetition;
    return null;
}

/// Operation: lineTo
pub fn call_lineTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: arcTo
pub fn call_arcTo(instance: *runtime.Instance, x1: f64, y1: f64, x2: f64, y2: f64, radius: f64) anyerror!void {
    _ = instance;
    _ = x1;
    _ = y1;
    _ = x2;
    _ = y2;
    _ = radius;
    return error.NotImplemented;
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
/// TypeError, each item by ToNumber - before the method's steps run. (This
/// used to take null and undefined as "clear", and to stop iterating at the
/// first invalid item, so a later item's valueOf never ran.)
pub fn call_setLineDash(instance: *runtime.Instance, segments: runtime.JSValue) anyerror!void {
    const internal = try getOrCreateInternal(instance);
    const allocator = instance.ctx.allocator;

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
    if (internal.line_dash.len > 0) allocator.free(internal.line_dash);
    internal.line_dash = dash;
}

/// Operation: moveTo
pub fn call_moveTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: quadraticCurveTo
pub fn call_quadraticCurveTo(instance: *runtime.Instance, cpx: f64, cpy: f64, x: f64, y: f64) anyerror!void {
    _ = instance;
    _ = cpx;
    _ = cpy;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: bezierCurveTo
pub fn call_bezierCurveTo(instance: *runtime.Instance, cp1x: f64, cp1y: f64, cp2x: f64, cp2y: f64, x: f64, y: f64) anyerror!void {
    _ = instance;
    _ = cp1x;
    _ = cp1y;
    _ = cp2x;
    _ = cp2y;
    _ = x;
    _ = y;
    return error.NotImplemented;
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
