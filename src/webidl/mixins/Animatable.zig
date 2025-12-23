//! Auto-generated mixin: Animatable
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const AnimatableImpl = @import("impls").Animatable;

// Re-export types from impl
pub const impl = @import("impls").Animatable;

pub fn call_getAnimations(instance: *runtime.Instance, options: dictionaries.GetAnimationsOptions) anyerror!void {
    return AnimatableImpl.call_getAnimations(instance, options);
}

pub fn call_animate(instance: *runtime.Instance, keyframes: ?runtime.JSValue, options: runtime.JSValue) !*runtime.Instance {
    return AnimatableImpl.call_animate(instance, keyframes, options);
}

