//! Auto-generated mixin: CanvasShadowStyles
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasShadowStylesImpl = @import("impls").CanvasShadowStyles;

// Re-export types from impl
pub const impl = @import("impls").CanvasShadowStyles;

pub fn get_shadowOffsetX(instance: *runtime.Instance) anyerror!f64 {
    return CanvasShadowStylesImpl.get_shadowOffsetX(instance);
}

pub fn set_shadowOffsetX(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return CanvasShadowStylesImpl.set_shadowOffsetX(instance, value);
}

pub fn get_shadowOffsetY(instance: *runtime.Instance) anyerror!f64 {
    return CanvasShadowStylesImpl.get_shadowOffsetY(instance);
}

pub fn set_shadowOffsetY(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return CanvasShadowStylesImpl.set_shadowOffsetY(instance, value);
}

pub fn get_shadowBlur(instance: *runtime.Instance) anyerror!f64 {
    return CanvasShadowStylesImpl.get_shadowBlur(instance);
}

pub fn set_shadowBlur(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return CanvasShadowStylesImpl.set_shadowBlur(instance, value);
}

pub fn get_shadowColor(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return CanvasShadowStylesImpl.get_shadowColor(instance);
}

pub fn set_shadowColor(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return CanvasShadowStylesImpl.set_shadowColor(instance, value);
}

