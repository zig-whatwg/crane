//! Implementation for AnimationTimeline interface (Web Animations 1 6.2;
//! Web Animations 2's currentTime, duration and play()).
//!
//! The timeline's model (dom.animations.model.Timeline) is this impl's,
//! made with every AnimationTimeline - a DocumentTimeline's included - and
//! reached by the rest of Crane through dom.animations.hooks.
//!
//! Spec: https://drafts.csswg.org/web-animations-1/#the-animationtimeline-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const animations = @import("dom").animations;
const AnimationTimeline = interfaces.AnimationTimeline;

pub const State = AnimationTimeline.State;

pub const ImplError = error{
    NotImplemented,
};

/// The timeline's model.
pub const InternalState = animations.model.Timeline;

fn timelineOf(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

pub fn installHooks() void {
    animations.hooks.installTimeline(&timelineOf);
}

/// AnimationTimeline's own construction steps: its model.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    const timeline = try allocator.create(InternalState);
    timeline.* = .{ .allocator = allocator, .instance = instance };
    instance.getState(State).own._internal = timeline;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const timeline = state.own._internal orelse return;
    state.own._internal = null;
    timeline.allocator.destroy(timeline);
}

/// Getter for currentTime: the timeline's current time, null while
/// inactive (6.2).
pub fn get_currentTime(instance: *runtime.Instance) anyerror!?typedefs.CSSNumberish {
    const timeline = timelineOf(instance) orelse return null;
    const time = timeline.currentTime() orelse return null;
    return .{ .double = time };
}

/// Getter for duration (Web Animations 2): a document timeline has none.
pub fn get_duration(instance: *runtime.Instance) anyerror!?typedefs.CSSNumberish {
    _ = instance;
    return null;
}

/// Operation: play (Web Animations 2 6.2): a new Animation with this
/// timeline and `effect`, played.
pub fn call_play(instance: *runtime.Instance, effect: webidl.Opt(?*runtime.Instance)) anyerror!*runtime.Instance {
    const realm = instance.ctx;
    const animation_instance = try interfaces.Animation.init(realm.allocator, realm);
    errdefer animation_instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(animation_instance));
    const new_effect: ?*runtime.Instance = if (effect.was_passed) effect.value else null;
    try animations.constructAnimation(animation_instance, new_effect, .{ .value = instance });
    const animation = animations.hooks.animationOf(animation_instance) orelse return error.InvalidStateError;
    try animation.play(true);
    return animation_instance;
}
