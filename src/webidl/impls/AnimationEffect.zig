//! Implementation for AnimationEffect interface (Web Animations 1 6.5; Web
//! Animations 2's timing hierarchy members).
//!
//! The effect's model (dom.animations.model.Effect) is this impl's, made
//! with every AnimationEffect - a KeyframeEffect's included - and reached by
//! the rest of Crane through dom.animations.hooks.
//!
//! Spec: https://drafts.csswg.org/web-animations-1/#the-animationeffect-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const animations = @import("dom").animations;
const AnimationEffect = interfaces.AnimationEffect;

pub const State = AnimationEffect.State;

pub const ImplError = error{
    NotImplemented,
};

/// The effect's model.
pub const InternalState = animations.model.Effect;

fn effectOf(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

pub fn installHooks() void {
    animations.hooks.installEffect(&effectOf);
}

/// AnimationEffect's own construction steps: its model, with the default
/// timing properties.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    const effect = try allocator.create(InternalState);
    effect.* = .{ .allocator = allocator, .instance = instance };
    instance.getState(State).own._internal = effect;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const effect = state.own._internal orelse return;
    state.own._internal = null;
    // The traced edge to its target goes with the effect (safe in teardown:
    // a collected effect's went with its wrapper).
    effect.setTarget(null);
    effect.deinit();
    effect.allocator.destroy(effect);
}

fn modelOf(instance: *runtime.Instance) !*InternalState {
    return effectOf(instance) orelse error.InvalidStateError;
}

/// Getter for parent (Web Animations 2): no group effects in Crane.
pub fn get_parent(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for previousSibling (Web Animations 2).
pub fn get_previousSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for nextSibling (Web Animations 2).
pub fn get_nextSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Operation: updateTiming (6.5.4).
pub fn call_updateTiming(instance: *runtime.Instance, timing: webidl.Opt(dictionaries.OptionalEffectTiming)) anyerror!void {
    const effect = try modelOf(instance);
    const allocator = instance.ctx.allocator;
    var easing_text: std.ArrayList(u8) = .empty;
    defer easing_text.deinit(allocator);
    const input = try animations.options.fromOptionalEffectTiming(instance.ctx, timing.getOrDefault(.{}), &easing_text, allocator);
    try animations.options.updateTiming(effect, input);
}

/// Operation: replace (Web Animations 2): "If there is no parent group,
/// abort these steps" - and no effect has one in Crane.
pub fn call_replace(instance: *runtime.Instance, effects: []const *runtime.Instance) anyerror!void {
    _ = instance;
    _ = effects;
}

/// Operation: before (Web Animations 2): no parent group, nothing to do.
pub fn call_before(instance: *runtime.Instance, effects: []const *runtime.Instance) anyerror!void {
    _ = instance;
    _ = effects;
}

/// Operation: after (Web Animations 2): no parent group, nothing to do.
pub fn call_after(instance: *runtime.Instance, effects: []const *runtime.Instance) anyerror!void {
    _ = instance;
    _ = effects;
}

/// Operation: remove (Web Animations 2): out of its parent group or its
/// animation.
pub fn call_remove(instance: *runtime.Instance) anyerror!void {
    const effect = try modelOf(instance);
    if (effect.animationModel()) |animation| animation.setEffect(null);
}

/// Operation: getTiming (6.5): the specified timing properties.
pub fn call_getTiming(instance: *runtime.Instance) anyerror!dictionaries.EffectTiming {
    const effect = try modelOf(instance);
    const t = &effect.timing;
    return .{
        .delay = t.delay,
        .endDelay = t.end_delay,
        .fill = animations.options.fillEnum(t.fill),
        .iterationStart = t.iteration_start,
        .iterations = t.iterations,
        .duration = if (t.duration) |d| .{ .number = d } else runtime.JSValue.fromStringRef("auto"),
        .direction = animations.options.directionEnum(t.direction),
        .easing = runtime.DOMString.initInterned(t.easing.text),
        .playbackRate = 1,
    };
}

/// Operation: getComputedTiming (6.5, 6.5.5): the timing model's values now.
pub fn call_getComputedTiming(instance: *runtime.Instance) anyerror!dictionaries.ComputedEffectTiming {
    const effect = try modelOf(instance);
    const t = &effect.timing;
    const computed = effect.computed();
    const has_animation = effect.animationModel() != null;
    return .{
        .base = .{
            .delay = t.delay,
            .endDelay = t.end_delay,
            // "auto" is the fill used for timing: none.
            .fill = animations.options.fillEnum(t.computedFill()),
            .iterationStart = t.iteration_start,
            .iterations = t.iterations,
            // The iteration duration: "auto" is zero.
            .duration = .{ .number = t.iterationDuration() },
            .direction = animations.options.directionEnum(t.direction),
            .easing = runtime.DOMString.initInterned(t.easing.text),
            .playbackRate = 1,
        },
        .endTime = .{ .double = t.endTime() },
        .activeDuration = .{ .double = t.activeDuration() },
        .localTime = if (has_animation) (if (effect.localTime()) |local| typedefs.CSSNumberish{ .double = local } else null) else null,
        .progress = computed.progress,
        .currentIteration = computed.current_iteration,
    };
}
