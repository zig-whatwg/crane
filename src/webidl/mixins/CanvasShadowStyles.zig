//! Auto-generated mixin: CanvasShadowStyles
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasShadowStylesImpl = @import("impls").CanvasShadowStyles;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").CanvasShadowStyles;

pub fn get_shadowOffsetX(instance: *runtime.Instance) anyerror!f64 {
    return try CanvasShadowStylesImpl.get_shadowOffsetX(instance);
}

pub fn set_shadowOffsetX(instance: *runtime.Instance, value: f64) anyerror!void {
    try CanvasShadowStylesImpl.set_shadowOffsetX(instance, value);
}

pub fn get_shadowOffsetY(instance: *runtime.Instance) anyerror!f64 {
    return try CanvasShadowStylesImpl.get_shadowOffsetY(instance);
}

pub fn set_shadowOffsetY(instance: *runtime.Instance, value: f64) anyerror!void {
    try CanvasShadowStylesImpl.set_shadowOffsetY(instance, value);
}

pub fn get_shadowBlur(instance: *runtime.Instance) anyerror!f64 {
    return try CanvasShadowStylesImpl.get_shadowBlur(instance);
}

pub fn set_shadowBlur(instance: *runtime.Instance, value: f64) anyerror!void {
    try CanvasShadowStylesImpl.set_shadowBlur(instance, value);
}

pub fn get_shadowColor(instance: *runtime.Instance) anyerror!DOMString {
    return try CanvasShadowStylesImpl.get_shadowColor(instance);
}

pub fn set_shadowColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
    try CanvasShadowStylesImpl.set_shadowColor(instance, value);
}
