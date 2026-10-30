//! Implementation for Animation interface (Web Animations 1 4.5, 6.4; Web
//! Animations 2's startTime/currentTime types and overallProgress).
//!
//! The animation's model and every procedure of 4.5 are
//! dom.animations.model.Animation's, owned here (made in initOwn, freed in
//! deinitOwn) and reached by the rest of Crane through dom.animations.hooks.
//! onfinish, oncancel and onremove are the generated event handlers
//! (dom.event_handlers).
//!
//! Spec: https://drafts.csswg.org/web-animations-1/#the-animation-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const animations = @import("dom").animations;
const Animation = interfaces.Animation;

pub const State = Animation.State;

pub const ImplError = error{
    NotImplemented,
};

/// The animation's model.
pub const InternalState = animations.model.Animation;

fn animationOf(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

fn modelOf(instance: *runtime.Instance) !*InternalState {
    return animationOf(instance) orelse error.InvalidStateError;
}

pub fn installHooks() void {
    animations.hooks.installAnimation(&animationOf);
}

/// Animation's own construction steps: its model (CSSAnimation and
/// CSSTransition run these too).
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    const animation = try allocator.create(InternalState);
    animation.* = .{ .allocator = allocator, .instance = instance };
    instance.getState(State).own._internal = animation;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const animation = state.own._internal orelse return;
    state.own._internal = null;
    // Its edges (timeline, effect, promises) go with it; forgetting an edge
    // is safe in teardown (a collected owner's went with its wrapper). The
    // effect it leaves no longer has an associated animation.
    if (animation.effectModel()) |effect| effect.animation = null;
    if (animation.timeline != null) @import("engine").forgetTracedChild(instance, InternalState.timeline_slot);
    if (animation.effect != null) @import("engine").forgetTracedChild(instance, InternalState.effect_slot);
    animation.deinit(true);
    animation.allocator.destroy(animation);
}

/// Constructor (6.4): Animation(effect, timeline).
pub fn call_constructor(ctx: runtime.Context, effect: webidl.Opt(?*runtime.Instance), timeline: webidl.Opt(?*runtime.Instance)) !*runtime.Instance {
    const instance = try Animation.init(ctx.allocator, ctx);
    errdefer instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
    const new_effect: ?*runtime.Instance = if (effect.was_passed) effect.value else null;
    const new_timeline: animations.options.EffectOptions.TimelineMember = if (timeline.was_passed) .{ .value = timeline.value } else .missing;
    try animations.constructAnimation(instance, new_effect, new_timeline);
    return instance;
}

/// Getter for id
pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const animation = try modelOf(instance);
    return runtime.DOMString.initInterned(animation.id);
}

/// Setter for id
pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const animation = try modelOf(instance);
    const copy = try animation.allocator.dupe(u8, value.asSlice());
    if (animation.id.len != 0) animation.allocator.free(animation.id);
    animation.id = copy;
}

/// Getter for effect: the associated effect.
pub fn get_effect(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const animation = try modelOf(instance);
    const link = animation.effect orelse return null;
    return link.get();
}

/// Setter for effect: "set the associated effect of an animation" (4.5.3).
pub fn set_effect(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    const animation = try modelOf(instance);
    animation.setEffect(value);
}

/// Getter for timeline.
pub fn get_timeline(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const animation = try modelOf(instance);
    const link = animation.timeline orelse return null;
    return link.get();
}

/// Setter for timeline: "set the timeline of an animation" (4.5.2).
pub fn set_timeline(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    const animation = try modelOf(instance);
    animation.setTimeline(value);
}

/// Getter for startTime.
pub fn get_startTime(instance: *runtime.Instance) anyerror!?typedefs.CSSNumberish {
    const animation = try modelOf(instance);
    const time = animation.start_time orelse return null;
    return .{ .double = time };
}

/// Getter for currentTime.
pub fn get_currentTime(instance: *runtime.Instance) anyerror!?typedefs.CSSNumberish {
    const animation = try modelOf(instance);
    const time = animation.currentTime() orelse return null;
    return .{ .double = time };
}

/// Getter for playbackRate.
pub fn get_playbackRate(instance: *runtime.Instance) anyerror!f64 {
    const animation = try modelOf(instance);
    return animation.playback_rate;
}

/// Getter for playState (4.5.17).
pub fn get_playState(instance: *runtime.Instance) anyerror!enums.AnimationPlayState {
    const animation = try modelOf(instance);
    return @enumFromInt(@intFromEnum(animation.playState()));
}

/// Getter for replaceState (5.5.1).
pub fn get_replaceState(instance: *runtime.Instance) anyerror!enums.AnimationReplaceState {
    const animation = try modelOf(instance);
    return @enumFromInt(@intFromEnum(animation.replace_state));
}

/// Getter for pending: a pending play or pause task.
pub fn get_pending(instance: *runtime.Instance) anyerror!bool {
    const animation = try modelOf(instance);
    return animation.hasPendingTask();
}

/// Getter for ready: the current ready promise (4.5.7).
pub fn get_ready(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const animation = try modelOf(instance);
    return (try animation.ready.get(instance)).take();
}

/// Getter for finished: the current finished promise (4.5.11).
pub fn get_finished(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const animation = try modelOf(instance);
    return (try animation.finished.get(instance)).take();
}

/// Getter for trigger (Animation Triggers): none in Crane.
pub fn get_trigger(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for overallProgress (Web Animations 2 2.3.11).
pub fn get_overallProgress(instance: *runtime.Instance) anyerror!?f64 {
    const animation = try modelOf(instance);
    if (animation.effectModel() == null) return null;
    const current = animation.currentTime() orelse return null;
    const end = animation.effectEnd();
    if (end == 0) return if (current < 0) 0 else 1;
    if (std.math.isInf(end)) return 0;
    return @min(@max(current / end, 0), 1);
}

/// Setter for startTime: "set the start time" (4.5.5). A CSSNumericValue
/// is a TypeError for a document timeline here (Typed OM time values are
/// not converted).
pub fn set_startTime(instance: *runtime.Instance, value: ?typedefs.CSSNumberish) anyerror!void {
    const animation = try modelOf(instance);
    animation.setStartTime(try timeOf(value));
}

/// Setter for currentTime: "set the current time" (4.5.4).
pub fn set_currentTime(instance: *runtime.Instance, value: ?typedefs.CSSNumberish) anyerror!void {
    const animation = try modelOf(instance);
    try animation.setCurrentTime(try timeOf(value));
}

fn timeOf(value: ?typedefs.CSSNumberish) !?f64 {
    const given = value orelse return null;
    return switch (given) {
        .double => |time| time,
        .cssnumeric_value => error.TypeError,
    };
}

/// Setter for playbackRate: "set the playback rate" (4.5.15.1).
pub fn set_playbackRate(instance: *runtime.Instance, value: f64) anyerror!void {
    const animation = try modelOf(instance);
    animation.setPlaybackRate(value);
}

/// Setter for trigger (Animation Triggers): not supported.
pub fn set_trigger(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: reverse (4.5.16).
pub fn call_reverse(instance: *runtime.Instance) anyerror!void {
    const animation = try modelOf(instance);
    try animation.reverse();
}

/// Operation: persist: the replace state becomes persisted.
pub fn call_persist(instance: *runtime.Instance) anyerror!void {
    const animation = try modelOf(instance);
    animation.persist();
}

/// Operation: commitStyles (6.4). NOT IMPLEMENTED: it writes the effect
/// values, and applying keyframe values (interpolation, the effect stack) is
/// the next Web Animations piece (rendering2 design delta, section 1).
pub fn call_commitStyles(instance: *runtime.Instance) anyerror!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: pause (4.5.9).
pub fn call_pause(instance: *runtime.Instance) anyerror!void {
    const animation = try modelOf(instance);
    try animation.pause();
}

/// Operation: play (4.5.8) with auto-rewind.
pub fn call_play(instance: *runtime.Instance) anyerror!void {
    const animation = try modelOf(instance);
    try animation.play(true);
}

/// Operation: cancel (4.5.14).
pub fn call_cancel(instance: *runtime.Instance) anyerror!void {
    const animation = try modelOf(instance);
    animation.cancel();
}

/// Operation: finish (4.5.13).
pub fn call_finish(instance: *runtime.Instance) anyerror!void {
    const animation = try modelOf(instance);
    try animation.finish();
}

/// Operation: updatePlaybackRate (4.5.15.2).
pub fn call_updatePlaybackRate(instance: *runtime.Instance, playbackRate: f64) anyerror!void {
    const animation = try modelOf(instance);
    animation.updatePlaybackRate(playbackRate);
}
