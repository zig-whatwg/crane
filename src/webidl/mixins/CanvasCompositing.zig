//! Auto-generated mixin: CanvasCompositing
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasCompositingImpl = @import("impls").CanvasCompositing;

// Re-export types from impl
pub const impl = @import("impls").CanvasCompositing;

pub fn get_globalAlpha(instance: *runtime.Instance) anyerror!f64 {
    return CanvasCompositingImpl.get_globalAlpha(instance);
}

pub fn set_globalAlpha(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return CanvasCompositingImpl.set_globalAlpha(instance, value);
}

pub fn get_globalCompositeOperation(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return CanvasCompositingImpl.get_globalCompositeOperation(instance);
}

pub fn set_globalCompositeOperation(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return CanvasCompositingImpl.set_globalCompositeOperation(instance, value);
}

