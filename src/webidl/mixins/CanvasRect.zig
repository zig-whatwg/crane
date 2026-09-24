//! Auto-generated mixin: CanvasRect
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasRectImpl = @import("impls").CanvasRect;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").CanvasRect;

pub fn call_strokeRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
    return try CanvasRectImpl.call_strokeRect(instance, x, y, w, h);
}

pub fn call_fillRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
    return try CanvasRectImpl.call_fillRect(instance, x, y, w, h);
}

pub fn call_clearRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
    return try CanvasRectImpl.call_clearRect(instance, x, y, w, h);
}
