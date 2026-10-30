//! Implementation for KeyframeEffect interface (Web Animations 1 6.6).
//!
//! A KeyframeEffect's state - its target, pseudo-element, composite
//! operation and keyframes - is the effect model's (AnimationEffect's impl
//! makes it; dom.animations.model.Effect). Applying its values to style is a
//! later piece: getKeyframes() returns what was specified.
//!
//! Spec: https://drafts.csswg.org/web-animations-1/#the-keyframeeffect-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const engine = @import("engine");
const animations = @import("dom").animations;
const KeyframeEffect = interfaces.KeyframeEffect;

pub const State = KeyframeEffect.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

fn modelOf(instance: *runtime.Instance) !*animations.model.Effect {
    return animations.hooks.effectOf(instance) orelse error.InvalidStateError;
}

/// Constructor (6.6): KeyframeEffect(target, keyframes, options) or
/// KeyframeEffect(source).
pub fn call_constructor(ctx: runtime.Context, args: interfaces.KeyframeEffect.ConstructorArgs) !*runtime.Instance {
    switch (args) {
        .Element_object_union => |given| {
            // The options argument converts before the steps run.
            var converted = try animations.options.effectOptions(ctx, if (given.options.was_passed) given.options.value else null, ctx.allocator, false);
            defer converted.deinit(ctx.allocator);
            const instance = try KeyframeEffect.init(ctx.allocator, ctx);
            errdefer instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
            try animations.constructKeyframeEffect(instance, given.target, given.keyframes, &converted);
            return instance;
        },
        .KeyframeEffect => |source| {
            const instance = try KeyframeEffect.init(ctx.allocator, ctx);
            errdefer instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
            try animations.copyKeyframeEffect(instance, source);
            return instance;
        },
    }
}

/// Getter for target: the target element.
pub fn get_target(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const effect = try modelOf(instance);
    return effect.targetElement();
}

/// Getter for pseudoElement: the target pseudo-selector, or null.
pub fn get_pseudoElement(instance: *runtime.Instance) anyerror!?typedefs.CSSOMString {
    const effect = try modelOf(instance);
    const pseudo = effect.pseudo orelse return null;
    return runtime.DOMString.initInterned(pseudo);
}

/// Getter for composite.
pub fn get_composite(instance: *runtime.Instance) anyerror!enums.CompositeOperation {
    const effect = try modelOf(instance);
    return @enumFromInt(@intFromEnum(effect.composite));
}

/// Getter for iterationComposite (Web Animations 2).
pub fn get_iterationComposite(instance: *runtime.Instance) anyerror!enums.IterationCompositeOperation {
    const effect = try modelOf(instance);
    return if (effect.iteration_accumulate) ._accumulate_ else ._replace_;
}

/// Setter for target: the effect target changes.
pub fn set_target(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    const effect = try modelOf(instance);
    effect.setTarget(value);
    if (effect.animationModel()) |animation| animation.settle();
}

/// Setter for pseudoElement: "pseudo-element parsing"; a SyntaxError leaves
/// the target pseudo-selector unchanged.
pub fn set_pseudoElement(instance: *runtime.Instance, value: ?typedefs.CSSOMString) anyerror!void {
    const effect = try modelOf(instance);
    const parsed = try animations.options.parsePseudoElement(effect.allocator, if (value) |v| v.asSlice() else null);
    if (effect.pseudo) |old| effect.allocator.free(old);
    effect.pseudo = parsed;
    animations.registry.valuesChanged(instance.ctx);
}

/// Setter for composite.
pub fn set_composite(instance: *runtime.Instance, value: enums.CompositeOperation) anyerror!void {
    const effect = try modelOf(instance);
    effect.composite = @enumFromInt(@intFromEnum(value));
    animations.registry.valuesChanged(instance.ctx);
}

/// Setter for iterationComposite (Web Animations 2).
pub fn set_iterationComposite(instance: *runtime.Instance, value: enums.IterationCompositeOperation) anyerror!void {
    const effect = try modelOf(instance);
    effect.iteration_accumulate = value == ._accumulate_;
    animations.registry.valuesChanged(instance.ctx);
}

/// Operation: setKeyframes (6.6): "process a keyframes argument"; an
/// exception leaves the keyframes unchanged.
pub fn call_setKeyframes(instance: *runtime.Instance, keyframes: ?runtime.JSValue) anyerror!void {
    const effect = try modelOf(instance);
    try animations.setKeyframes(effect, keyframes);
    animations.registry.valuesChanged(instance.ctx);
}

/// Operation: getKeyframes (6.6): the keyframes with their computed
/// offsets, as new objects in the current realm.
pub fn call_getKeyframes(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const effect = try modelOf(instance);
    const realm = engine.currentRealm() orelse instance.ctx;
    const result = try animations.keyframes.toObjects(realm, instance.ctx.allocator, &effect.keyframes);
    return result.take();
}
