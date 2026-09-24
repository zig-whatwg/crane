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
    defer v8.ffi.v8_Context_Dispose(context);

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
    var values: std.ArrayList(f64) = .empty;
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
    defer v8.ffi.v8_Context_Dispose(context);

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

    // Check if it's an object (required for iteration protocol).
    //
    // On the Global itself: every v8_* function here takes a Global<Value>*.
    // This used to call v8_Global_Get first, which returns a LOCAL slot
    // pointer merely typed *Value, and pass that on - one level of indirection
    // off, so v8_Value_IsObject read an object's first word as a handle and
    // crashed (webidl/ecmascript-binding/sequence-conversion.html).
    if (!v8.ffi.v8_Value_IsObject(v8_global)) {
        return error.TypeError;
    }
    const obj: *v8.ffi.Object = @ptrCast(v8_global);

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
