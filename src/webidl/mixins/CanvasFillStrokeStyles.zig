//! Auto-generated mixin: CanvasFillStrokeStyles
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasFillStrokeStylesImpl = @import("impls").CanvasFillStrokeStyles;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CanvasGradient = @import("interfaces").CanvasGradient;
const CanvasImageSource = @import("typedefs").CanvasImageSource;
const CanvasPattern = @import("interfaces").CanvasPattern;
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").CanvasFillStrokeStyles;

pub fn get_strokeStyle(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return try CanvasFillStrokeStylesImpl.get_strokeStyle(instance);
}

pub fn set_strokeStyle(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    try CanvasFillStrokeStylesImpl.set_strokeStyle(instance, value);
}

pub fn get_fillStyle(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return try CanvasFillStrokeStylesImpl.get_fillStyle(instance);
}

pub fn set_fillStyle(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
    try CanvasFillStrokeStylesImpl.set_fillStyle(instance, value);
}

pub fn call_createRadialGradient(instance: *runtime.Instance, x0: f64, y0: f64, r0: f64, x1: f64, y1: f64, r1: f64) anyerror!*runtime.Instance {
    return try CanvasFillStrokeStylesImpl.call_createRadialGradient(instance, x0, y0, r0, x1, y1, r1);
}

pub fn call_createConicGradient(instance: *runtime.Instance, startAngle: f64, x: f64, y: f64) anyerror!*runtime.Instance {
    return try CanvasFillStrokeStylesImpl.call_createConicGradient(instance, startAngle, x, y);
}

pub fn call_createLinearGradient(instance: *runtime.Instance, x0: f64, y0: f64, x1: f64, y1: f64) anyerror!*runtime.Instance {
    return try CanvasFillStrokeStylesImpl.call_createLinearGradient(instance, x0, y0, x1, y1);
}

pub fn call_createPattern(instance: *runtime.Instance, image: CanvasImageSource, repetition: DOMString) anyerror!?*runtime.Instance {
    return try CanvasFillStrokeStylesImpl.call_createPattern(instance, image, repetition);
}

/// WebIDL [LegacyNullToEmptyString]: the values null converts to "" for
/// (bit i = argument i; an attribute setter's value is bit 0).
pub const legacy_null_to_empty = .{
    .{ "call_createPattern", 0b10 },
};
