//! Auto-generated mixin: CanvasPathDrawingStyles
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasPathDrawingStylesImpl = @import("impls").CanvasPathDrawingStyles;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CanvasLineJoin = @import("enums").CanvasLineJoin;
const CanvasLineCap = @import("enums").CanvasLineCap;

pub const impl = @import("impls").CanvasPathDrawingStyles;

pub fn get_lineWidth(instance: *runtime.Instance) anyerror!f64 {
    return try CanvasPathDrawingStylesImpl.get_lineWidth(instance);
}

pub fn set_lineWidth(instance: *runtime.Instance, value: f64) anyerror!void {
    try CanvasPathDrawingStylesImpl.set_lineWidth(instance, value);
}

pub fn get_lineCap(instance: *runtime.Instance) anyerror!CanvasLineCap {
    return try CanvasPathDrawingStylesImpl.get_lineCap(instance);
}

pub fn set_lineCap(instance: *runtime.Instance, value: CanvasLineCap) anyerror!void {
    try CanvasPathDrawingStylesImpl.set_lineCap(instance, value);
}

pub fn get_lineJoin(instance: *runtime.Instance) anyerror!CanvasLineJoin {
    return try CanvasPathDrawingStylesImpl.get_lineJoin(instance);
}

pub fn set_lineJoin(instance: *runtime.Instance, value: CanvasLineJoin) anyerror!void {
    try CanvasPathDrawingStylesImpl.set_lineJoin(instance, value);
}

pub fn get_miterLimit(instance: *runtime.Instance) anyerror!f64 {
    return try CanvasPathDrawingStylesImpl.get_miterLimit(instance);
}

pub fn set_miterLimit(instance: *runtime.Instance, value: f64) anyerror!void {
    try CanvasPathDrawingStylesImpl.set_miterLimit(instance, value);
}

pub fn get_lineDashOffset(instance: *runtime.Instance) anyerror!f64 {
    return try CanvasPathDrawingStylesImpl.get_lineDashOffset(instance);
}

pub fn set_lineDashOffset(instance: *runtime.Instance, value: f64) anyerror!void {
    try CanvasPathDrawingStylesImpl.set_lineDashOffset(instance, value);
}

pub fn call_getLineDash(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return try CanvasPathDrawingStylesImpl.call_getLineDash(instance);
}

pub fn call_setLineDash(instance: *runtime.Instance, segments: runtime.JSValue) anyerror!void {
    return try CanvasPathDrawingStylesImpl.call_setLineDash(instance, segments);
}
