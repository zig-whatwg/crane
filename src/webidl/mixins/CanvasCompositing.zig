//! Auto-generated mixin: CanvasCompositing
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasCompositingImpl = @import("impls").CanvasCompositing;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").CanvasCompositing;

pub fn get_globalAlpha(instance: *runtime.Instance) anyerror!f64 {
    return try CanvasCompositingImpl.get_globalAlpha(instance);
}

pub fn set_globalAlpha(instance: *runtime.Instance, value: f64) anyerror!void {
    try CanvasCompositingImpl.set_globalAlpha(instance, value);
}

pub fn get_globalCompositeOperation(instance: *runtime.Instance) anyerror!DOMString {
    return try CanvasCompositingImpl.get_globalCompositeOperation(instance);
}

pub fn set_globalCompositeOperation(instance: *runtime.Instance, value: DOMString) anyerror!void {
    try CanvasCompositingImpl.set_globalCompositeOperation(instance, value);
}
