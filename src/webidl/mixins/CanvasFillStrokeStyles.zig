//! Auto-generated mixin: CanvasFillStrokeStyles
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasFillStrokeStylesImpl = @import("impls").CanvasFillStrokeStyles;

// Re-export types from impl
pub const impl = @import("impls").CanvasFillStrokeStyles;

pub fn get_strokeStyle(instance: *runtime.Instance) anyerror!void {
    return CanvasFillStrokeStylesImpl.get_strokeStyle(instance);
}

pub fn set_strokeStyle(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return CanvasFillStrokeStylesImpl.set_strokeStyle(instance, value);
}

pub fn get_fillStyle(instance: *runtime.Instance) anyerror!void {
    return CanvasFillStrokeStylesImpl.get_fillStyle(instance);
}

pub fn set_fillStyle(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return CanvasFillStrokeStylesImpl.set_fillStyle(instance, value);
}

pub fn call_createRadialGradient(instance: *runtime.Instance, x0: runtime.JSValue, y0: runtime.JSValue, r0: runtime.JSValue, x1: runtime.JSValue, y1: runtime.JSValue, r1: runtime.JSValue) !*runtime.Instance {
    return CanvasFillStrokeStylesImpl.call_createRadialGradient(instance, x0, y0, r0, x1, y1, r1);
}

pub fn call_createConicGradient(instance: *runtime.Instance, startAngle: runtime.JSValue, x: runtime.JSValue, y: runtime.JSValue) !*runtime.Instance {
    return CanvasFillStrokeStylesImpl.call_createConicGradient(instance, startAngle, x, y);
}

pub fn call_createLinearGradient(instance: *runtime.Instance, x0: runtime.JSValue, y0: runtime.JSValue, x1: runtime.JSValue, y1: runtime.JSValue) !*runtime.Instance {
    return CanvasFillStrokeStylesImpl.call_createLinearGradient(instance, x0, y0, x1, y1);
}

pub fn call_createPattern(instance: *runtime.Instance, image: typedefs.CanvasImageSource, repetition: typedefs.DOMString) !?*runtime.Instance {
    return CanvasFillStrokeStylesImpl.call_createPattern(instance, image, repetition);
}

