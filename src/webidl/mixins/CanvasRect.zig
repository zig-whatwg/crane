//! Auto-generated mixin: CanvasRect
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasRectImpl = @import("impls").CanvasRect;

// Re-export types from impl
pub const impl = @import("impls").CanvasRect;

pub fn call_strokeRect(instance: *runtime.Instance, x: runtime.JSValue, y: runtime.JSValue, w: runtime.JSValue, h: runtime.JSValue) anyerror!void {
    return CanvasRectImpl.call_strokeRect(instance, x, y, w, h);
}

pub fn call_fillRect(instance: *runtime.Instance, x: runtime.JSValue, y: runtime.JSValue, w: runtime.JSValue, h: runtime.JSValue) anyerror!void {
    return CanvasRectImpl.call_fillRect(instance, x, y, w, h);
}

pub fn call_clearRect(instance: *runtime.Instance, x: runtime.JSValue, y: runtime.JSValue, w: runtime.JSValue, h: runtime.JSValue) anyerror!void {
    return CanvasRectImpl.call_clearRect(instance, x, y, w, h);
}

