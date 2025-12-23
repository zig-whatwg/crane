//! Auto-generated mixin: CanvasPath
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasPathImpl = @import("impls").CanvasPath;

// Re-export types from impl
pub const impl = @import("impls").CanvasPath;

pub fn call_arc(instance: *runtime.Instance, x: runtime.JSValue, y: runtime.JSValue, radius: runtime.JSValue, startAngle: runtime.JSValue, endAngle: runtime.JSValue, counterclockwise: runtime.JSValue) anyerror!void {
    return CanvasPathImpl.call_arc(instance, x, y, radius, startAngle, endAngle, counterclockwise);
}

pub fn call_rect(instance: *runtime.Instance, x: runtime.JSValue, y: runtime.JSValue, w: runtime.JSValue, h: runtime.JSValue) anyerror!void {
    return CanvasPathImpl.call_rect(instance, x, y, w, h);
}

pub fn call_closePath(instance: *runtime.Instance) anyerror!void {
    return CanvasPathImpl.call_closePath(instance);
}

pub fn call_moveTo(instance: *runtime.Instance, x: runtime.JSValue, y: runtime.JSValue) anyerror!void {
    return CanvasPathImpl.call_moveTo(instance, x, y);
}

pub fn call_bezierCurveTo(instance: *runtime.Instance, cp1x: runtime.JSValue, cp1y: runtime.JSValue, cp2x: runtime.JSValue, cp2y: runtime.JSValue, x: runtime.JSValue, y: runtime.JSValue) anyerror!void {
    return CanvasPathImpl.call_bezierCurveTo(instance, cp1x, cp1y, cp2x, cp2y, x, y);
}

pub fn call_roundRect(instance: *runtime.Instance, x: runtime.JSValue, y: runtime.JSValue, w: runtime.JSValue, h: runtime.JSValue, radii: runtime.JSValue) anyerror!void {
    return CanvasPathImpl.call_roundRect(instance, x, y, w, h, radii);
}

pub fn call_quadraticCurveTo(instance: *runtime.Instance, cpx: runtime.JSValue, cpy: runtime.JSValue, x: runtime.JSValue, y: runtime.JSValue) anyerror!void {
    return CanvasPathImpl.call_quadraticCurveTo(instance, cpx, cpy, x, y);
}

pub fn call_ellipse(instance: *runtime.Instance, x: runtime.JSValue, y: runtime.JSValue, radiusX: runtime.JSValue, radiusY: runtime.JSValue, rotation: runtime.JSValue, startAngle: runtime.JSValue, endAngle: runtime.JSValue, counterclockwise: runtime.JSValue) anyerror!void {
    return CanvasPathImpl.call_ellipse(instance, x, y, radiusX, radiusY, rotation, startAngle, endAngle, counterclockwise);
}

pub fn call_lineTo(instance: *runtime.Instance, x: runtime.JSValue, y: runtime.JSValue) anyerror!void {
    return CanvasPathImpl.call_lineTo(instance, x, y);
}

pub fn call_arcTo(instance: *runtime.Instance, x1: runtime.JSValue, y1: runtime.JSValue, x2: runtime.JSValue, y2: runtime.JSValue, radius: runtime.JSValue) anyerror!void {
    return CanvasPathImpl.call_arcTo(instance, x1, y1, x2, y2, radius);
}

