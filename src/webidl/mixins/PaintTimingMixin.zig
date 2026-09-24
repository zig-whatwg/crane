//! Auto-generated mixin: PaintTimingMixin
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PaintTimingMixinImpl = @import("impls").PaintTimingMixin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;

pub const impl = @import("impls").PaintTimingMixin;

pub fn get_paintTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
    return try PaintTimingMixinImpl.get_paintTime(instance);
}

pub fn get_presentationTime(instance: *runtime.Instance) anyerror!?DOMHighResTimeStamp {
    return try PaintTimingMixinImpl.get_presentationTime(instance);
}
