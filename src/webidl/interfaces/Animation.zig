//! Generated from: web-animations.idl
//! Generated at: 2025-11-24T18:47:07Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AnimationImpl = @import("impls").Animation;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const AnimationPlayState = @import("enums").AnimationPlayState;
const TimelineRangeOffset = @import("dictionaries").TimelineRangeOffset;
const CSSKeywordValue = @import("interfaces").CSSKeywordValue;
const AnimationTrigger = @import("interfaces").AnimationTrigger;
const AnimationTimeline = @import("interfaces").AnimationTimeline;
const Observable = @import("interfaces").Observable;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const Event = @import("interfaces").Event;
const AnimationEffect = @import("interfaces").AnimationEffect;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AnimationReplaceState = @import("enums").AnimationReplaceState;
const EventListener = @import("interfaces").EventListener;
const CSSNumberish = @import("typedefs").CSSNumberish;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const Animation = struct {
    pub const Meta = struct {
        pub const name = "Animation";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "id", "get_id", "set_id" },
            .{ "effect", "get_effect", "set_effect" },
            .{ "timeline", "get_timeline", "set_timeline" },
            .{ "startTime", "get_startTime", "set_startTime" },
            .{ "currentTime", "get_currentTime", "set_currentTime" },
            .{ "playbackRate", "get_playbackRate", "set_playbackRate" },
            .{ "playState", "get_playState", null },
            .{ "replaceState", "get_replaceState", null },
            .{ "pending", "get_pending", null },
            .{ "ready", "get_ready", null },
            .{ "finished", "get_finished", null },
            .{ "onfinish", "get_onfinish", "set_onfinish" },
            .{ "oncancel", "get_oncancel", "set_oncancel" },
            .{ "onremove", "get_onremove", "set_onremove" },
            .{ "startTime", "get_startTime", "set_startTime" },
            .{ "currentTime", "get_currentTime", "set_currentTime" },
            .{ "trigger", "get_trigger", "set_trigger" },
            .{ "rangeStart", "get_rangeStart", "set_rangeStart" },
            .{ "rangeEnd", "get_rangeEnd", "set_rangeEnd" },
            .{ "overallProgress", "get_overallProgress", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "cancel", "call_cancel", 0 },
            .{ "finish", "call_finish", 0 },
            .{ "play", "call_play", 0 },
            .{ "pause", "call_pause", 0 },
            .{ "updatePlaybackRate", "call_updatePlaybackRate", 1 },
            .{ "reverse", "call_reverse", 0 },
            .{ "persist", "call_persist", 0 },
            .{ "commitStyles", "call_commitStyles", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "cancel",
            "finish",
            "play",
            "pause",
            "updatePlaybackRate",
            "reverse",
            "persist",
            "commitStyles",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "id", "get_id", "set_id" },
            .{ "effect", "get_effect", "set_effect" },
            .{ "timeline", "get_timeline", "set_timeline" },
            .{ "startTime", "get_startTime", "set_startTime" },
            .{ "currentTime", "get_currentTime", "set_currentTime" },
            .{ "playbackRate", "get_playbackRate", "set_playbackRate" },
            .{ "playState", "get_playState", null },
            .{ "replaceState", "get_replaceState", null },
            .{ "pending", "get_pending", null },
            .{ "ready", "get_ready", null },
            .{ "finished", "get_finished", null },
            .{ "onfinish", "get_onfinish", "set_onfinish" },
            .{ "oncancel", "get_oncancel", "set_oncancel" },
            .{ "onremove", "get_onremove", "set_onremove" },
            .{ "startTime", "get_startTime", "set_startTime" },
            .{ "currentTime", "get_currentTime", "set_currentTime" },
            .{ "trigger", "get_trigger", "set_trigger" },
            .{ "rangeStart", "get_rangeStart", "set_rangeStart" },
            .{ "rangeEnd", "get_rangeEnd", "set_rangeEnd" },
            .{ "overallProgress", "get_overallProgress", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            id: runtime.DOMString = undefined,
            effect: ?*runtime.Instance = null,
            timeline: ?*runtime.Instance = null,
            startTime: ?f64 = null,
            currentTime: ?f64 = null,
            playbackRate: f64 = undefined,
            playState: AnimationPlayState = undefined,
            replaceState: AnimationReplaceState = undefined,
            pending: bool = undefined,
            ready: runtime.Promise(Animation) = undefined,
            finished: runtime.Promise(Animation) = undefined,
            onfinish: EventHandler = undefined,
            oncancel: EventHandler = undefined,
            onremove: EventHandler = undefined,
            trigger: ?*runtime.Instance = null,
            rangeStart: union(enum) {
                TimelineRangeOffset: TimelineRangeOffset,
                CSSNumericValue: CSSNumericValue,
                CSSKeywordValue: CSSKeywordValue,
                DOMString: runtime.DOMString,
            } = undefined,
            rangeEnd: union(enum) {
                TimelineRangeOffset: TimelineRangeOffset,
                CSSNumericValue: CSSNumericValue,
                CSSKeywordValue: CSSKeywordValue,
                DOMString: runtime.DOMString,
            } = undefined,
            overallProgress: ?f64 = null,
            _internal: ?*AnimationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_currentTime = &get_currentTime,
        .get_effect = &get_effect,
        .get_finished = &get_finished,
        .get_id = &get_id,
        .get_oncancel = &get_oncancel,
        .get_onfinish = &get_onfinish,
        .get_onremove = &get_onremove,
        .get_overallProgress = &get_overallProgress,
        .get_pending = &get_pending,
        .get_playState = &get_playState,
        .get_playbackRate = &get_playbackRate,
        .get_rangeEnd = &get_rangeEnd,
        .get_rangeStart = &get_rangeStart,
        .get_ready = &get_ready,
        .get_replaceState = &get_replaceState,
        .get_startTime = &get_startTime,
        .get_timeline = &get_timeline,
        .get_trigger = &get_trigger,

        .set_currentTime = &set_currentTime,
        .set_effect = &set_effect,
        .set_id = &set_id,
        .set_oncancel = &set_oncancel,
        .set_onfinish = &set_onfinish,
        .set_onremove = &set_onremove,
        .set_playbackRate = &set_playbackRate,
        .set_rangeEnd = &set_rangeEnd,
        .set_rangeStart = &set_rangeStart,
        .set_startTime = &set_startTime,
        .set_timeline = &set_timeline,
        .set_trigger = &set_trigger,

        .call_cancel = &call_cancel,
        .call_commitStyles = &call_commitStyles,
        .call_finish = &call_finish,
        .call_pause = &call_pause,
        .call_persist = &call_persist,
        .call_play = &call_play,
        .call_reverse = &call_reverse,
        .call_updatePlaybackRate = &call_updatePlaybackRate,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AnimationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AnimationImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, effect: *runtime.Instance, timeline: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AnimationImpl.call_constructor(allocator, ctx, effect, timeline);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try AnimationImpl.get_id(instance);
    }

    pub fn set_id(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try AnimationImpl.set_id(instance, value);
    }

    pub fn get_effect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AnimationImpl.get_effect(instance);
    }

    pub fn set_effect(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try AnimationImpl.set_effect(instance, value);
    }

    pub fn get_timeline(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AnimationImpl.get_timeline(instance);
    }

    pub fn set_timeline(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try AnimationImpl.set_timeline(instance, value);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!f64 {
        return try AnimationImpl.get_startTime(instance);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: f64) anyerror!void {
        try AnimationImpl.set_startTime(instance, value);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!f64 {
        return try AnimationImpl.get_currentTime(instance);
    }

    pub fn set_currentTime(instance: *runtime.Instance, value: f64) anyerror!void {
        try AnimationImpl.set_currentTime(instance, value);
    }

    pub fn get_playbackRate(instance: *runtime.Instance) anyerror!f64 {
        return try AnimationImpl.get_playbackRate(instance);
    }

    pub fn set_playbackRate(instance: *runtime.Instance, value: f64) anyerror!void {
        try AnimationImpl.set_playbackRate(instance, value);
    }

    pub fn get_playState(instance: *runtime.Instance) anyerror!AnimationPlayState {
        return try AnimationImpl.get_playState(instance);
    }

    pub fn get_replaceState(instance: *runtime.Instance) anyerror!AnimationReplaceState {
        return try AnimationImpl.get_replaceState(instance);
    }

    pub fn get_pending(instance: *runtime.Instance) anyerror!bool {
        return try AnimationImpl.get_pending(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try AnimationImpl.get_ready(instance);
    }

    pub fn get_finished(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try AnimationImpl.get_finished(instance);
    }

    pub fn get_onfinish(instance: *runtime.Instance) anyerror!EventHandler {
        return try AnimationImpl.get_onfinish(instance);
    }

    pub fn set_onfinish(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AnimationImpl.set_onfinish(instance, value);
    }

    pub fn get_oncancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try AnimationImpl.get_oncancel(instance);
    }

    pub fn set_oncancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AnimationImpl.set_oncancel(instance, value);
    }

    pub fn get_onremove(instance: *runtime.Instance) anyerror!EventHandler {
        return try AnimationImpl.get_onremove(instance);
    }

    pub fn set_onremove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AnimationImpl.set_onremove(instance, value);
    }

    pub fn get_trigger(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AnimationImpl.get_trigger(instance);
    }

    pub fn set_trigger(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try AnimationImpl.set_trigger(instance, value);
    }

    pub fn get_rangeStart(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try AnimationImpl.get_rangeStart(instance);
    }

    pub fn set_rangeStart(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try AnimationImpl.set_rangeStart(instance, value);
    }

    pub fn get_rangeEnd(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try AnimationImpl.get_rangeEnd(instance);
    }

    pub fn set_rangeEnd(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try AnimationImpl.set_rangeEnd(instance, value);
    }

    pub fn get_overallProgress(instance: *runtime.Instance) anyerror!f64 {
        return try AnimationImpl.get_overallProgress(instance);
    }

    pub fn call_reverse(instance: *runtime.Instance) anyerror!void {
        return try AnimationImpl.call_reverse(instance);
    }

    pub fn call_persist(instance: *runtime.Instance) anyerror!void {
        return try AnimationImpl.call_persist(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_commitStyles(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try AnimationImpl.call_commitStyles(instance);
    }

    pub fn call_pause(instance: *runtime.Instance) anyerror!void {
        return try AnimationImpl.call_pause(instance);
    }

    pub fn call_play(instance: *runtime.Instance) anyerror!void {
        return try AnimationImpl.call_play(instance);
    }

    pub fn call_cancel(instance: *runtime.Instance) anyerror!void {
        return try AnimationImpl.call_cancel(instance);
    }

    pub fn call_finish(instance: *runtime.Instance) anyerror!void {
        return try AnimationImpl.call_finish(instance);
    }

    pub fn call_updatePlaybackRate(instance: *runtime.Instance, playbackRate: f64) anyerror!void {
        
        return try AnimationImpl.call_updatePlaybackRate(instance, playbackRate);
    }

};
