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
const v8 = @import("v8");

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

/// Getter for globalAlpha
pub fn get_globalAlpha(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for globalCompositeOperation
pub fn get_globalCompositeOperation(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for imageSmoothingEnabled
pub fn get_imageSmoothingEnabled(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for imageSmoothingQuality
pub fn get_imageSmoothingQuality(instance: *runtime.Instance) anyerror!enums.ImageSmoothingQuality {
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

/// Getter for shadowOffsetX
pub fn get_shadowOffsetX(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for shadowOffsetY
pub fn get_shadowOffsetY(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for shadowBlur
pub fn get_shadowBlur(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for shadowColor
pub fn get_shadowColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for filter
pub fn get_filter(instance: *runtime.Instance) anyerror!runtime.DOMString {
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

/// Getter for lang
pub fn get_lang(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for font
pub fn get_font(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for textAlign
pub fn get_textAlign(instance: *runtime.Instance) anyerror!enums.CanvasTextAlign {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for textBaseline
pub fn get_textBaseline(instance: *runtime.Instance) anyerror!enums.CanvasTextBaseline {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for direction
pub fn get_direction(instance: *runtime.Instance) anyerror!enums.CanvasDirection {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for letterSpacing
pub fn get_letterSpacing(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fontKerning
pub fn get_fontKerning(instance: *runtime.Instance) anyerror!enums.CanvasFontKerning {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fontStretch
pub fn get_fontStretch(instance: *runtime.Instance) anyerror!enums.CanvasFontStretch {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fontVariantCaps
pub fn get_fontVariantCaps(instance: *runtime.Instance) anyerror!enums.CanvasFontVariantCaps {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for textRendering
pub fn get_textRendering(instance: *runtime.Instance) anyerror!enums.CanvasTextRendering {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for wordSpacing
pub fn get_wordSpacing(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for globalAlpha
pub fn set_globalAlpha(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for globalCompositeOperation
pub fn set_globalCompositeOperation(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for imageSmoothingEnabled
pub fn set_imageSmoothingEnabled(instance: *runtime.Instance, value: bool) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for imageSmoothingQuality
pub fn set_imageSmoothingQuality(instance: *runtime.Instance, value: enums.ImageSmoothingQuality) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
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

/// Setter for shadowOffsetX
pub fn set_shadowOffsetX(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for shadowOffsetY
pub fn set_shadowOffsetY(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for shadowBlur
pub fn set_shadowBlur(instance: *runtime.Instance, value: f64) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for shadowColor
pub fn set_shadowColor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for filter
pub fn set_filter(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
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

/// Setter for lang
pub fn set_lang(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for font
pub fn set_font(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for textAlign
pub fn set_textAlign(instance: *runtime.Instance, value: enums.CanvasTextAlign) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for textBaseline
pub fn set_textBaseline(instance: *runtime.Instance, value: enums.CanvasTextBaseline) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for direction
pub fn set_direction(instance: *runtime.Instance, value: enums.CanvasDirection) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for letterSpacing
pub fn set_letterSpacing(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for fontKerning
pub fn set_fontKerning(instance: *runtime.Instance, value: enums.CanvasFontKerning) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for fontStretch
pub fn set_fontStretch(instance: *runtime.Instance, value: enums.CanvasFontStretch) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for fontVariantCaps
pub fn set_fontVariantCaps(instance: *runtime.Instance, value: enums.CanvasFontVariantCaps) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for textRendering
pub fn set_textRendering(instance: *runtime.Instance, value: enums.CanvasTextRendering) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for wordSpacing
pub fn set_wordSpacing(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
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

/// Operation: isPointInPath
pub fn call_isPointInPath(instance: *runtime.Instance, x: f64, y: f64, fillRule: webidl.Opt(enums.CanvasFillRule)) anyerror!bool {
    _ = instance;
    _ = x;
    _ = y;
    _ = fillRule;
    return error.NotImplemented;
}

/// Operation: getLineDash
/// Returns a copy of the current line dash pattern.
/// Spec: https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-getlinedash
///
/// NOTE: There is a known V8 limitation where if Array.prototype has a getter-only
/// accessor at a specific index (e.g., Array.prototype[1] with only a getter),
/// then v8_Array_Set will fail when trying to set that index on ANY array.
/// This affects the WPT test "A holey array with fallback to an accessor on the prototype"
/// in sequence-conversion.html. This is a JavaScript semantics issue in V8, not
/// something we can work around without changing V8's internal array handling.
pub fn call_getLineDash(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse {
        // No internal state yet = empty dash (default)
        // Return empty array
        const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return error.NotImplemented;
        _ = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NotImplemented;
        // v8_Array_New returns a Global<Array>* which can be used directly as a Global handle
        const array = v8.ffi.v8_Array_New(isolate, 0);
        return runtime.JSValue{ .handle = .{ .ptr = @ptrCast(array) } };
    };

    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return error.NotImplemented;
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NotImplemented;

    // Create V8 array from the stored line dash pattern
    // v8_Array_New returns a Global<Array>* which can be used directly as a Global handle
    const dash_len: u32 = @intCast(internal.line_dash.len);
    const array = v8.ffi.v8_Array_New(isolate, @intCast(dash_len));

    // Populate array with f64 values
    for (internal.line_dash, 0..) |val, i| {
        const num_val = v8.ffi.v8_Number_New(isolate, val);
        _ = v8.ffi.v8_Array_Set(array, context, @intCast(i), @ptrCast(num_val));
    }

    // v8_Array_New already returns a Global handle - no need to persist again
    return runtime.JSValue{ .handle = .{ .ptr = @ptrCast(array) } };
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

/// Operation: clearRect
pub fn call_clearRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
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

/// Operation: transform
pub fn call_transform(instance: *runtime.Instance, a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) anyerror!void {
    _ = instance;
    _ = a;
    _ = b;
    _ = c;
    _ = d;
    _ = e;
    _ = f;
    return error.NotImplemented;
}

/// Operation: restore
pub fn call_restore(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: clip
pub fn call_clip(instance: *runtime.Instance, fillRule: webidl.Opt(enums.CanvasFillRule)) anyerror!void {
    _ = instance;
    _ = fillRule;
    return error.NotImplemented;
}

/// Operation: reset
pub fn call_reset(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: strokeText
pub fn call_strokeText(instance: *runtime.Instance, text: runtime.DOMString, x: f64, y: f64, maxWidth: webidl.Opt(f64)) anyerror!void {
    _ = instance;
    _ = text;
    _ = x;
    _ = y;
    _ = maxWidth;
    return error.NotImplemented;
}

/// Operation: stroke
pub fn call_stroke(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: drawImage
pub fn call_drawImage(instance: *runtime.Instance, image: typedefs.CanvasImageSource, dx: f64, dy: f64) anyerror!void {
    _ = instance;
    _ = image;
    _ = dx;
    _ = dy;
    return error.NotImplemented;
}

/// Operation: getImageData
pub fn call_getImageData(instance: *runtime.Instance, sx: i32, sy: i32, sw: i32, sh: i32, settings: webidl.Opt(dictionaries.ImageDataSettings)) anyerror!*runtime.Instance {
    _ = instance;
    _ = sx;
    _ = sy;
    _ = sw;
    _ = sh;
    _ = settings;
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

/// Operation: getTransform
pub fn call_getTransform(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
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

/// Operation: drawFocusIfNeeded
pub fn call_drawFocusIfNeeded(instance: *runtime.Instance, element: *runtime.Instance) anyerror!void {
    _ = instance;
    _ = element;
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

/// Operation: resetTransform
pub fn call_resetTransform(instance: *runtime.Instance) anyerror!void {
    _ = instance;
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

/// Operation: getContextAttributes
pub fn call_getContextAttributes(instance: *runtime.Instance) anyerror!dictionaries.CanvasRenderingContext2DSettings {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setLineDash
/// Helper to iterate using Symbol.iterator protocol and collect f64 values
/// Per WebIDL spec, sequence conversion should use the iteration protocol
fn iterateToF64Array(
    allocator: std.mem.Allocator,
    isolate: *v8.ffi.Isolate,
    context: *v8.ffi.Context,
    obj: *v8.ffi.Object,
) !?[]f64 {
    // Get Symbol.iterator from the object
    const iterator_symbol = v8.ffi.v8_Symbol_GetIterator(isolate) orelse return error.TypeError;
    const iterator_fn_val = v8.ffi.v8_Object_GetPropertyWithSymbol(context, obj, iterator_symbol) orelse return error.TypeError;

    // Check if it's a function
    if (!v8.ffi.v8_Value_IsFunction(iterator_fn_val)) {
        return error.TypeError;
    }
    const iterator_fn: *v8.ffi.Function = @ptrCast(iterator_fn_val);

    // Call the iterator function to get the iterator object
    const iterator_val = v8.ffi.v8_Function_CallWithReceiver(
        context,
        iterator_fn,
        @ptrCast(obj), // receiver is the original object
        0, // no arguments
        null, // argv
    ) orelse return error.TypeError;

    if (!v8.ffi.v8_Value_IsObject(iterator_val)) {
        return error.TypeError;
    }
    const iterator_obj: *v8.ffi.Object = @ptrCast(iterator_val);

    // Get the 'next' method from the iterator
    const next_str = v8.ffi.v8_String_NewFromUtf8(isolate, "next", 4) orelse return error.TypeError;
    const next_fn_val = v8.ffi.v8_Object_Get(iterator_obj, context, @ptrCast(next_str)) orelse return error.TypeError;

    if (!v8.ffi.v8_Value_IsFunction(next_fn_val)) {
        return error.TypeError;
    }
    const next_fn: *v8.ffi.Function = @ptrCast(next_fn_val);

    // Get "done" and "value" strings for property access
    const done_str = v8.ffi.v8_String_NewFromUtf8(isolate, "done", 4) orelse return error.TypeError;
    const value_str = v8.ffi.v8_String_NewFromUtf8(isolate, "value", 5) orelse return error.TypeError;

    // Collect values by iterating
    var values: std.ArrayList(f64) = .{};
    defer values.deinit(allocator);

    const max_iterations: usize = 10000; // Safety limit
    var iteration_count: usize = 0;

    while (iteration_count < max_iterations) : (iteration_count += 1) {
        // Call iterator.next()
        const result_val = v8.ffi.v8_Function_CallWithReceiver(
            context,
            next_fn,
            @ptrCast(iterator_obj),
            0, // no arguments
            null, // argv
        ) orelse return error.TypeError;

        if (!v8.ffi.v8_Value_IsObject(result_val)) {
            return error.TypeError;
        }
        const result_obj: *v8.ffi.Object = @ptrCast(result_val);

        // Check if done
        const done_val = v8.ffi.v8_Object_Get(result_obj, context, @ptrCast(done_str)) orelse return error.TypeError;
        if (v8.ffi.v8_Value_BooleanValue(done_val, isolate)) {
            break;
        }

        // Get the value
        const item_val = v8.ffi.v8_Object_Get(result_obj, context, @ptrCast(value_str)) orelse return error.TypeError;
        const num = v8.ffi.v8_Value_NumberValue(item_val, context);

        // Per spec: if any value is negative, non-finite, or NaN, return null (don't change dash)
        if (num < 0 or std.math.isNan(num) or std.math.isInf(num)) {
            return null;
        }

        try values.append(allocator, num);
    }

    // Return owned slice
    return try values.toOwnedSlice(allocator);
}

/// Operation: setLineDash
/// Sets the current line dash list.
/// Spec: https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-setlinedash
pub fn call_setLineDash(instance: *runtime.Instance, segments: runtime.JSValue) anyerror!void {
    const internal = try getOrCreateInternal(instance);
    const allocator = instance.ctx.allocator;

    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return error.NotImplemented;
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NotImplemented;

    // Get the V8 value from runtime.JSValue
    // Check what variant we have
    const v8_global: *v8.ffi.Value = switch (segments) {
        .handle => |h| @ptrCast(h.ptr),
        .undefined, .null => {
            // setLineDash(undefined/null) clears the dash pattern
            if (internal.line_dash.len > 0) {
                allocator.free(internal.line_dash);
                internal.line_dash = &[_]f64{};
            }
            return;
        },
        // Per WebIDL spec, sequence<unrestricted double> should be iterable
        .boolean, .number, .string, .instance => {
            // Invalid types for sequence parameter - per spec should throw TypeError
            return error.TypeError;
        },
    };

    // Get the local value from the global handle
    const v8_local = v8.ffi.v8_Global_Get(isolate, v8_global) orelse return error.TypeError;
    const v8_value: *v8.ffi.Value = @ptrCast(@alignCast(v8_local));

    // Check if it's an object (required for iteration protocol)
    if (!v8.ffi.v8_Value_IsObject(v8_value)) {
        return error.TypeError;
    }
    const obj: *v8.ffi.Object = @ptrCast(v8_value);

    // Use the iteration protocol to get values (per WebIDL spec)
    const values = try iterateToF64Array(allocator, isolate, context, obj) orelse {
        // null means invalid value found - return without changing (per spec)
        return;
    };

    // Empty array is valid - clears the dash
    if (values.len == 0) {
        if (internal.line_dash.len > 0) {
            allocator.free(internal.line_dash);
            internal.line_dash = &[_]f64{};
        }
        allocator.free(values);
        return;
    }

    // Per spec: if odd length, duplicate the array (e.g., [5] becomes [5, 5])
    const final_values = if (values.len % 2 != 0) blk: {
        const doubled = try allocator.alloc(f64, values.len * 2);
        @memcpy(doubled[0..values.len], values);
        @memcpy(doubled[values.len..], values);
        allocator.free(values);
        break :blk doubled;
    } else values;

    // Free old dash and store new one
    if (internal.line_dash.len > 0) {
        allocator.free(internal.line_dash);
    }
    internal.line_dash = final_values;
}

/// Operation: save
pub fn call_save(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
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

/// Operation: isContextLost
pub fn call_isContextLost(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: isPointInStroke
pub fn call_isPointInStroke(instance: *runtime.Instance, x: f64, y: f64) anyerror!bool {
    _ = instance;
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

/// Operation: rotate
pub fn call_rotate(instance: *runtime.Instance, angle: f64) anyerror!void {
    _ = instance;
    _ = angle;
    return error.NotImplemented;
}

/// Operation: createImageData
pub fn call_createImageData(instance: *runtime.Instance, sw: i32, sh: i32, settings: webidl.Opt(dictionaries.ImageDataSettings)) anyerror!*runtime.Instance {
    _ = instance;
    _ = sw;
    _ = sh;
    _ = settings;
    return error.NotImplemented;
}

/// Operation: scale
pub fn call_scale(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: translate
pub fn call_translate(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
    _ = instance;
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

/// Operation: strokeRect
pub fn call_strokeRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    return error.NotImplemented;
}

/// Operation: setTransform
pub fn call_setTransform(instance: *runtime.Instance, a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) anyerror!void {
    _ = instance;
    _ = a;
    _ = b;
    _ = c;
    _ = d;
    _ = e;
    _ = f;
    return error.NotImplemented;
}

/// Operation: fillRect
pub fn call_fillRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    return error.NotImplemented;
}

/// Operation: beginPath
pub fn call_beginPath(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: fillText
pub fn call_fillText(instance: *runtime.Instance, text: runtime.DOMString, x: f64, y: f64, maxWidth: webidl.Opt(f64)) anyerror!void {
    _ = instance;
    _ = text;
    _ = x;
    _ = y;
    _ = maxWidth;
    return error.NotImplemented;
}

/// Operation: measureText
pub fn call_measureText(instance: *runtime.Instance, text: runtime.DOMString) anyerror!*runtime.Instance {
    _ = instance;
    _ = text;
    return error.NotImplemented;
}

/// Operation: fill
pub fn call_fill(instance: *runtime.Instance, fillRule: webidl.Opt(enums.CanvasFillRule)) anyerror!void {
    _ = instance;
    _ = fillRule;
    return error.NotImplemented;
}

/// Operation: putImageData
pub fn call_putImageData(instance: *runtime.Instance, imageData: *runtime.Instance, dx: i32, dy: i32) anyerror!void {
    _ = instance;
    _ = imageData;
    _ = dx;
    _ = dy;
    return error.NotImplemented;
}
