//! Implementation for AnimationPlaybackEvent interface (Web Animations 1
//! 6.12): the finish, cancel and remove events, and script's own.
//!
//! Spec: https://drafts.csswg.org/web-animations-1/#the-animationplaybackevent-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const event_construction = @import("dom").event_construction;
const AnimationPlaybackEvent = interfaces.AnimationPlaybackEvent;

pub const State = AnimationPlaybackEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Nothing beyond the attributes, which the generated State holds.
pub const InternalState = struct {};

/// Constructor: DOM "inner event creation steps" with the EventInit part,
/// then currentTime and timelineTime from the dictionary (null by default).
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.AnimationPlaybackEventInit)) !*runtime.Instance {
    const instance = try AnimationPlaybackEvent.init(ctx.allocator, ctx);
    errdefer AnimationPlaybackEvent.deinit(instance);
    const dict: dictionaries.AnimationPlaybackEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{} };
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(dict.base));
    const state = instance.getState(State);
    state.own.currentTime = timeOf(dict.currentTime);
    state.own.timelineTime = timeOf(dict.timelineTime);
    return instance;
}

/// A time as the event keeps it: a number, or null. (A CSSNumericValue is
/// not kept: it would need a hold of its own.)
fn timeOf(value: ?typedefs.CSSNumberish) ?typedefs.CSSNumberish {
    const given = value orelse return null;
    return switch (given) {
        .double => given,
        .cssnumeric_value => null,
    };
}

/// Getter for currentTime: the animation's current time when the event was
/// queued, or null.
pub fn get_currentTime(instance: *runtime.Instance) anyerror!?typedefs.CSSNumberish {
    return instance.getState(State).own.currentTime;
}

/// Getter for timelineTime: its timeline's time when the event was queued,
/// or null.
pub fn get_timelineTime(instance: *runtime.Instance) anyerror!?typedefs.CSSNumberish {
    return instance.getState(State).own.timelineTime;
}
