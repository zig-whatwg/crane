//! Generated from: web-animations.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AnimationImpl = @import("impls").Animation;
const EventTarget = @import("interfaces").EventTarget;
const EventHandler = @import("typedefs").EventHandler;
const AnimationEffect = @import("interfaces").AnimationEffect;
const AnimationPlayState = @import("enums").AnimationPlayState;
const (TimelineRangeOffset or CSSNumericValue or CSSKeywordValue or DOMString) = @import("interfaces").(TimelineRangeOffset or CSSNumericValue or CSSKeywordValue or DOMString);
const AnimationReplaceState = @import("enums").AnimationReplaceState;
const AnimationTrigger = @import("interfaces").AnimationTrigger;
const CSSNumberish = @import("typedefs").CSSNumberish;
const AnimationTimeline = @import("interfaces").AnimationTimeline;
const double = @import("interfaces").double;
const Promise<Animation> = @import("interfaces").Promise<Animation>;

pub const Animation = struct {
    pub const Meta = struct {
        pub const name = "Animation";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            id: runtime.DOMString = undefined,
            effect: ?AnimationEffect = null,
            timeline: ?AnimationTimeline = null,
            startTime: ?f64 = null,
            currentTime: ?f64 = null,
            playbackRate: f64 = undefined,
            playState: AnimationPlayState = undefined,
            replaceState: AnimationReplaceState = undefined,
            pending: bool = undefined,
            ready: Promise<Animation> = undefined,
            finished: Promise<Animation> = undefined,
            onfinish: EventHandler = undefined,
            oncancel: EventHandler = undefined,
            onremove: EventHandler = undefined,
            startTime: ?CSSNumberish = null,
            currentTime: ?CSSNumberish = null,
            trigger: ?AnimationTrigger = null,
            rangeStart: (TimelineRangeOffset or CSSNumericValue or CSSKeywordValue or DOMString) = undefined,
            rangeEnd: (TimelineRangeOffset or CSSNumericValue or CSSKeywordValue or DOMString) = undefined,
            overallProgress: ?f64 = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Animation, .{
        .deinit_fn = &deinit_wrapper,

        .get_currentTime = &get_currentTime,
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
        .get_startTime = &get_startTime,
        .get_timeline = &get_timeline,
        .get_trigger = &get_trigger,

        .set_currentTime = &set_currentTime,
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
        .set_startTime = &set_startTime,
        .set_timeline = &set_timeline,
        .set_trigger = &set_trigger,

        .call_addEventListener = &call_addEventListener,
        .call_cancel = &call_cancel,
        .call_commitStyles = &call_commitStyles,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_finish = &call_finish,
        .call_pause = &call_pause,
        .call_persist = &call_persist,
        .call_play = &call_play,
        .call_removeEventListener = &call_removeEventListener,
        .call_reverse = &call_reverse,
        .call_updatePlaybackRate = &call_updatePlaybackRate,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        AnimationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AnimationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, effect: anyopaque, timeline: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try AnimationImpl.constructor(instance, effect, timeline);
        
        return instance;
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try AnimationImpl.get_id(instance);
    }

    pub fn set_id(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try AnimationImpl.set_id(instance, value);
    }

    pub fn get_effect(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationImpl.get_effect(instance);
    }

    pub fn set_effect(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try AnimationImpl.set_effect(instance, value);
    }

    pub fn get_timeline(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationImpl.get_timeline(instance);
    }

    pub fn set_timeline(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try AnimationImpl.set_timeline(instance, value);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationImpl.get_startTime(instance);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try AnimationImpl.set_startTime(instance, value);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationImpl.get_currentTime(instance);
    }

    pub fn set_currentTime(instance: *runtime.Instance, value: anyopaque) anyerror!void {
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

    pub fn get_ready(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationImpl.get_ready(instance);
    }

    pub fn get_finished(instance: *runtime.Instance) anyerror!anyopaque {
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

    pub fn get_startTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationImpl.get_startTime(instance);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try AnimationImpl.set_startTime(instance, value);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationImpl.get_currentTime(instance);
    }

    pub fn set_currentTime(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try AnimationImpl.set_currentTime(instance, value);
    }

    pub fn get_trigger(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationImpl.get_trigger(instance);
    }

    pub fn set_trigger(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try AnimationImpl.set_trigger(instance, value);
    }

    pub fn get_rangeStart(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationImpl.get_rangeStart(instance);
    }

    pub fn set_rangeStart(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try AnimationImpl.set_rangeStart(instance, value);
    }

    pub fn get_rangeEnd(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationImpl.get_rangeEnd(instance);
    }

    pub fn set_rangeEnd(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try AnimationImpl.set_rangeEnd(instance, value);
    }

    pub fn get_overallProgress(instance: *runtime.Instance) anyerror!anyopaque {
        return try AnimationImpl.get_overallProgress(instance);
    }

    pub fn call_updatePlaybackRate(instance: *runtime.Instance, playbackRate: f64) anyerror!void {
        
        return try AnimationImpl.call_updatePlaybackRate(instance, playbackRate);
    }

    pub fn call_reverse(instance: *runtime.Instance) anyerror!void {
        return try AnimationImpl.call_reverse(instance);
    }

    pub fn call_persist(instance: *runtime.Instance) anyerror!void {
        return try AnimationImpl.call_persist(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try AnimationImpl.call_when(instance, type_, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_commitStyles(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try AnimationImpl.call_commitStyles(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try AnimationImpl.call_dispatchEvent(instance, event);
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

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try AnimationImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try AnimationImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
