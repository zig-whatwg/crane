//! Auto-generated mixin: CanvasPath
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasPathImpl = @import("impls").CanvasPath;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMPointInit = @import("dictionaries").DOMPointInit;

pub const impl = @import("impls").CanvasPath;

pub fn call_arc(instance: *runtime.Instance, x: f64, y: f64, radius: f64, startAngle: f64, endAngle: f64, counterclockwise: webidl.Opt(bool)) anyerror!void {
    return try CanvasPathImpl.call_arc(instance, x, y, radius, startAngle, endAngle, counterclockwise);
}

pub fn call_rect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
    return try CanvasPathImpl.call_rect(instance, x, y, w, h);
}

pub fn call_closePath(instance: *runtime.Instance) anyerror!void {
    return try CanvasPathImpl.call_closePath(instance);
}

pub fn call_moveTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
    return try CanvasPathImpl.call_moveTo(instance, x, y);
}

pub fn call_bezierCurveTo(instance: *runtime.Instance, cp1x: f64, cp1y: f64, cp2x: f64, cp2y: f64, x: f64, y: f64) anyerror!void {
    return try CanvasPathImpl.call_bezierCurveTo(instance, cp1x, cp1y, cp2x, cp2y, x, y);
}

pub fn call_roundRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64, radii: webidl.Opt(runtime.JSValue)) anyerror!void {
    return try CanvasPathImpl.call_roundRect(instance, x, y, w, h, radii);
}

pub fn call_quadraticCurveTo(instance: *runtime.Instance, cpx: f64, cpy: f64, x: f64, y: f64) anyerror!void {
    return try CanvasPathImpl.call_quadraticCurveTo(instance, cpx, cpy, x, y);
}

pub fn call_ellipse(instance: *runtime.Instance, x: f64, y: f64, radiusX: f64, radiusY: f64, rotation: f64, startAngle: f64, endAngle: f64, counterclockwise: webidl.Opt(bool)) anyerror!void {
    return try CanvasPathImpl.call_ellipse(instance, x, y, radiusX, radiusY, rotation, startAngle, endAngle, counterclockwise);
}

pub fn call_lineTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
    return try CanvasPathImpl.call_lineTo(instance, x, y);
}

pub fn call_arcTo(instance: *runtime.Instance, x1: f64, y1: f64, x2: f64, y2: f64, radius: f64) anyerror!void {
    return try CanvasPathImpl.call_arcTo(instance, x1, y1, x2, y2, radius);
}
