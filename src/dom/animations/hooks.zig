//! The Web Animations objects' models, reached from their instances.
//!
//! Each model (model.zig) is OWNED by its interface's impl, made in its
//! initOwn and freed in its deinitOwn. The rest of Crane - the rendering
//! step, the other Web Animations types, Element and Document - reaches a
//! model through the hook its owner installs here, once, at process start,
//! and never names the impl (AGENTS.md "The impls boundary").
//!
//! lint-impls: hook for Animation, AnimationEffect, AnimationTimeline
const process_start = @import("../process_start.zig");
const runtime = @import("runtime");
const model = @import("model.zig");

/// What the owners install. Each answers null for an instance that is not
/// of its type, or whose model is gone.
pub const Hooks = struct {
    /// Animation (and its descendants CSSAnimation and CSSTransition).
    animation_of: ?*const fn (instance: *runtime.Instance) ?*model.Animation = null,
    /// AnimationEffect (and its descendant KeyframeEffect).
    effect_of: ?*const fn (instance: *runtime.Instance) ?*model.Effect = null,
    /// AnimationTimeline (and its descendant DocumentTimeline).
    timeline_of: ?*const fn (instance: *runtime.Instance) ?*model.Timeline = null,
};

// process-wide: function pointers the Web Animations impls install once at process start (crane.Process), the same for every Browser and thread; the models are their instances'
var hooks: Hooks = .{};

/// Called by Animation's installHooks (process_start.zig).
pub fn installAnimation(animation_of: *const fn (instance: *runtime.Instance) ?*model.Animation) void {
    process_start.assertInstalling();
    hooks.animation_of = animation_of;
}

/// Called by AnimationEffect's installHooks (process_start.zig).
pub fn installEffect(effect_of: *const fn (instance: *runtime.Instance) ?*model.Effect) void {
    process_start.assertInstalling();
    hooks.effect_of = effect_of;
}

/// Called by AnimationTimeline's installHooks (process_start.zig).
pub fn installTimeline(timeline_of: *const fn (instance: *runtime.Instance) ?*model.Timeline) void {
    process_start.assertInstalling();
    hooks.timeline_of = timeline_of;
}

pub fn animationOf(instance: *runtime.Instance) ?*model.Animation {
    const get = hooks.animation_of orelse return null;
    return get(instance);
}

pub fn effectOf(instance: *runtime.Instance) ?*model.Effect {
    const get = hooks.effect_of orelse return null;
    return get(instance);
}

pub fn timelineOf(instance: *runtime.Instance) ?*model.Timeline {
    const get = hooks.timeline_of orelse return null;
    return get(instance);
}
