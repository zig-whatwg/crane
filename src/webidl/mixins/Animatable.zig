//! Auto-generated mixin: Animatable
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AnimatableImpl = @import("impls").Animatable;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Animation = @import("interfaces").Animation;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;

pub const impl = @import("impls").Animatable;

pub fn call_getAnimations(instance: *runtime.Instance, options: webidl.Opt(GetAnimationsOptions)) anyerror!runtime.JSValue {
    return try AnimatableImpl.call_getAnimations(instance, options);
}

pub fn call_animate(instance: *runtime.Instance, keyframes: ?runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
    return try AnimatableImpl.call_animate(instance, keyframes, options);
}
