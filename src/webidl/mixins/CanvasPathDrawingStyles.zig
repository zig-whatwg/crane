//! Auto-generated mixin: CanvasPathDrawingStyles
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasPathDrawingStylesImpl = @import("impls").CanvasPathDrawingStyles;

// Re-export types from impl
pub const impl = @import("impls").CanvasPathDrawingStyles;

pub fn get_lineWidth(instance: *runtime.Instance) anyerror!f64 {
    return CanvasPathDrawingStylesImpl.get_lineWidth(instance);
}

pub fn set_lineWidth(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return CanvasPathDrawingStylesImpl.set_lineWidth(instance, value);
}

pub fn get_lineCap(instance: *runtime.Instance) anyerror!enums.CanvasLineCap {
    return CanvasPathDrawingStylesImpl.get_lineCap(instance);
}

pub fn set_lineCap(instance: *runtime.Instance, value: enums.CanvasLineCap) !void {
    return CanvasPathDrawingStylesImpl.set_lineCap(instance, value);
}

pub fn get_lineJoin(instance: *runtime.Instance) anyerror!enums.CanvasLineJoin {
    return CanvasPathDrawingStylesImpl.get_lineJoin(instance);
}

pub fn set_lineJoin(instance: *runtime.Instance, value: enums.CanvasLineJoin) !void {
    return CanvasPathDrawingStylesImpl.set_lineJoin(instance, value);
}

pub fn get_miterLimit(instance: *runtime.Instance) anyerror!f64 {
    return CanvasPathDrawingStylesImpl.get_miterLimit(instance);
}

pub fn set_miterLimit(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return CanvasPathDrawingStylesImpl.set_miterLimit(instance, value);
}

pub fn get_lineDashOffset(instance: *runtime.Instance) anyerror!f64 {
    return CanvasPathDrawingStylesImpl.get_lineDashOffset(instance);
}

pub fn set_lineDashOffset(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return CanvasPathDrawingStylesImpl.set_lineDashOffset(instance, value);
}

pub fn call_getLineDash(instance: *runtime.Instance) anyerror!void {
    return CanvasPathDrawingStylesImpl.call_getLineDash(instance);
}

pub fn call_setLineDash(instance: *runtime.Instance, segments: runtime.JSValue) anyerror!void {
    return CanvasPathDrawingStylesImpl.call_setLineDash(instance, segments);
}

