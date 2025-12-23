//! Auto-generated mixin: PaintTimingMixin
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const PaintTimingMixinImpl = @import("impls").PaintTimingMixin;

// Re-export types from impl
pub const impl = @import("impls").PaintTimingMixin;

pub fn get_paintTime(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return PaintTimingMixinImpl.get_paintTime(instance);
}

pub fn get_presentationTime(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return PaintTimingMixinImpl.get_presentationTime(instance);
}

