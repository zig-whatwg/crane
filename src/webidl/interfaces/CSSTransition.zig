//! Generated from: css-transitions-2.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSTransitionImpl = @import("impls").CSSTransition;
const Animation = @import("interfaces").Animation;
const CSSOMString = @import("interfaces").CSSOMString;

pub const CSSTransition = struct {
    pub const Meta = struct {
        pub const name = "CSSTransition";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Animation;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            transitionProperty: CSSOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSTransition, .{
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
        .get_transitionProperty = &get_transitionProperty,
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
        CSSTransitionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSTransitionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSTransitionImpl.get_id(instance);
    }

    pub fn set_id(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSSTransitionImpl.set_id(instance, value);
    }

    pub fn get_effect(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSTransitionImpl.get_effect(instance);
    }

    pub fn set_effect(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSTransitionImpl.set_effect(instance, value);
    }

    pub fn get_timeline(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSTransitionImpl.get_timeline(instance);
    }

    pub fn set_timeline(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSTransitionImpl.set_timeline(instance, value);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSTransitionImpl.get_startTime(instance);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSTransitionImpl.set_startTime(instance, value);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSTransitionImpl.get_currentTime(instance);
    }

    pub fn set_currentTime(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSTransitionImpl.set_currentTime(instance, value);
    }

    pub fn get_playbackRate(instance: *runtime.Instance) anyerror!f64 {
        return try CSSTransitionImpl.get_playbackRate(instance);
    }

    pub fn set_playbackRate(instance: *runtime.Instance, value: f64) anyerror!void {
        try CSSTransitionImpl.set_playbackRate(instance, value);
    }

    pub fn get_playState(instance: *runtime.Instance) anyerror!AnimationPlayState {
        return try CSSTransitionImpl.get_playState(instance);
    }

    pub fn get_replaceState(instance: *runtime.Instance) anyerror!AnimationReplaceState {
        return try CSSTransitionImpl.get_replaceState(instance);
    }

    pub fn get_pending(instance: *runtime.Instance) anyerror!bool {
        return try CSSTransitionImpl.get_pending(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSTransitionImpl.get_ready(instance);
    }

    pub fn get_finished(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSTransitionImpl.get_finished(instance);
    }

    pub fn get_onfinish(instance: *runtime.Instance) anyerror!EventHandler {
        return try CSSTransitionImpl.get_onfinish(instance);
    }

    pub fn set_onfinish(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try CSSTransitionImpl.set_onfinish(instance, value);
    }

    pub fn get_oncancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try CSSTransitionImpl.get_oncancel(instance);
    }

    pub fn set_oncancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try CSSTransitionImpl.set_oncancel(instance, value);
    }

    pub fn get_onremove(instance: *runtime.Instance) anyerror!EventHandler {
        return try CSSTransitionImpl.get_onremove(instance);
    }

    pub fn set_onremove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try CSSTransitionImpl.set_onremove(instance, value);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSTransitionImpl.get_startTime(instance);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSTransitionImpl.set_startTime(instance, value);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSTransitionImpl.get_currentTime(instance);
    }

    pub fn set_currentTime(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSTransitionImpl.set_currentTime(instance, value);
    }

    pub fn get_trigger(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSTransitionImpl.get_trigger(instance);
    }

    pub fn set_trigger(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSTransitionImpl.set_trigger(instance, value);
    }

    pub fn get_rangeStart(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSTransitionImpl.get_rangeStart(instance);
    }

    pub fn set_rangeStart(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSTransitionImpl.set_rangeStart(instance, value);
    }

    pub fn get_rangeEnd(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSTransitionImpl.get_rangeEnd(instance);
    }

    pub fn set_rangeEnd(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CSSTransitionImpl.set_rangeEnd(instance, value);
    }

    pub fn get_overallProgress(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSTransitionImpl.get_overallProgress(instance);
    }

    pub fn get_transitionProperty(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSTransitionImpl.get_transitionProperty(instance);
    }

    pub fn call_updatePlaybackRate(instance: *runtime.Instance, playbackRate: f64) anyerror!void {
        
        return try CSSTransitionImpl.call_updatePlaybackRate(instance, playbackRate);
    }

    pub fn call_reverse(instance: *runtime.Instance) anyerror!void {
        return try CSSTransitionImpl.call_reverse(instance);
    }

    pub fn call_persist(instance: *runtime.Instance) anyerror!void {
        return try CSSTransitionImpl.call_persist(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try CSSTransitionImpl.call_when(instance, type_, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_commitStyles(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try CSSTransitionImpl.call_commitStyles(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try CSSTransitionImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_pause(instance: *runtime.Instance) anyerror!void {
        return try CSSTransitionImpl.call_pause(instance);
    }

    pub fn call_play(instance: *runtime.Instance) anyerror!void {
        return try CSSTransitionImpl.call_play(instance);
    }

    pub fn call_cancel(instance: *runtime.Instance) anyerror!void {
        return try CSSTransitionImpl.call_cancel(instance);
    }

    pub fn call_finish(instance: *runtime.Instance) anyerror!void {
        return try CSSTransitionImpl.call_finish(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try CSSTransitionImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try CSSTransitionImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
