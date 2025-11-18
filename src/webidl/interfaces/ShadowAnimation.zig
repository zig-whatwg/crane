//! Generated from: SVG.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ShadowAnimationImpl = @import("impls").ShadowAnimation;
const Animation = @import("interfaces").Animation;

pub const ShadowAnimation = struct {
    pub const Meta = struct {
        pub const name = "ShadowAnimation";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Animation;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Constructor" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            sourceAnimation: Animation = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ShadowAnimation, .{
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
        .get_sourceAnimation = &get_sourceAnimation,
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
        ShadowAnimationImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ShadowAnimationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try ShadowAnimationImpl.get_id(instance);
    }

    pub fn set_id(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try ShadowAnimationImpl.set_id(instance, value);
    }

    pub fn get_effect(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowAnimationImpl.get_effect(instance);
    }

    pub fn set_effect(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try ShadowAnimationImpl.set_effect(instance, value);
    }

    pub fn get_timeline(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowAnimationImpl.get_timeline(instance);
    }

    pub fn set_timeline(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try ShadowAnimationImpl.set_timeline(instance, value);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowAnimationImpl.get_startTime(instance);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try ShadowAnimationImpl.set_startTime(instance, value);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowAnimationImpl.get_currentTime(instance);
    }

    pub fn set_currentTime(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try ShadowAnimationImpl.set_currentTime(instance, value);
    }

    pub fn get_playbackRate(instance: *runtime.Instance) anyerror!f64 {
        return try ShadowAnimationImpl.get_playbackRate(instance);
    }

    pub fn set_playbackRate(instance: *runtime.Instance, value: f64) anyerror!void {
        try ShadowAnimationImpl.set_playbackRate(instance, value);
    }

    pub fn get_playState(instance: *runtime.Instance) anyerror!AnimationPlayState {
        return try ShadowAnimationImpl.get_playState(instance);
    }

    pub fn get_replaceState(instance: *runtime.Instance) anyerror!AnimationReplaceState {
        return try ShadowAnimationImpl.get_replaceState(instance);
    }

    pub fn get_pending(instance: *runtime.Instance) anyerror!bool {
        return try ShadowAnimationImpl.get_pending(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowAnimationImpl.get_ready(instance);
    }

    pub fn get_finished(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowAnimationImpl.get_finished(instance);
    }

    pub fn get_onfinish(instance: *runtime.Instance) anyerror!EventHandler {
        return try ShadowAnimationImpl.get_onfinish(instance);
    }

    pub fn set_onfinish(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ShadowAnimationImpl.set_onfinish(instance, value);
    }

    pub fn get_oncancel(instance: *runtime.Instance) anyerror!EventHandler {
        return try ShadowAnimationImpl.get_oncancel(instance);
    }

    pub fn set_oncancel(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ShadowAnimationImpl.set_oncancel(instance, value);
    }

    pub fn get_onremove(instance: *runtime.Instance) anyerror!EventHandler {
        return try ShadowAnimationImpl.get_onremove(instance);
    }

    pub fn set_onremove(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ShadowAnimationImpl.set_onremove(instance, value);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowAnimationImpl.get_startTime(instance);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try ShadowAnimationImpl.set_startTime(instance, value);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowAnimationImpl.get_currentTime(instance);
    }

    pub fn set_currentTime(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try ShadowAnimationImpl.set_currentTime(instance, value);
    }

    pub fn get_trigger(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowAnimationImpl.get_trigger(instance);
    }

    pub fn set_trigger(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try ShadowAnimationImpl.set_trigger(instance, value);
    }

    pub fn get_rangeStart(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowAnimationImpl.get_rangeStart(instance);
    }

    pub fn set_rangeStart(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try ShadowAnimationImpl.set_rangeStart(instance, value);
    }

    pub fn get_rangeEnd(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowAnimationImpl.get_rangeEnd(instance);
    }

    pub fn set_rangeEnd(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try ShadowAnimationImpl.set_rangeEnd(instance, value);
    }

    pub fn get_overallProgress(instance: *runtime.Instance) anyerror!anyopaque {
        return try ShadowAnimationImpl.get_overallProgress(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_sourceAnimation(instance: *runtime.Instance) anyerror!Animation {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_sourceAnimation) |cached| {
            return cached;
        }
        const value = try ShadowAnimationImpl.get_sourceAnimation(instance);
        state.cached_sourceAnimation = value;
        return value;
    }

    pub fn call_updatePlaybackRate(instance: *runtime.Instance, playbackRate: f64) anyerror!void {
        
        return try ShadowAnimationImpl.call_updatePlaybackRate(instance, playbackRate);
    }

    pub fn call_reverse(instance: *runtime.Instance) anyerror!void {
        return try ShadowAnimationImpl.call_reverse(instance);
    }

    pub fn call_persist(instance: *runtime.Instance) anyerror!void {
        return try ShadowAnimationImpl.call_persist(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try ShadowAnimationImpl.call_when(instance, type_, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_commitStyles(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try ShadowAnimationImpl.call_commitStyles(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try ShadowAnimationImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_pause(instance: *runtime.Instance) anyerror!void {
        return try ShadowAnimationImpl.call_pause(instance);
    }

    pub fn call_play(instance: *runtime.Instance) anyerror!void {
        return try ShadowAnimationImpl.call_play(instance);
    }

    pub fn call_cancel(instance: *runtime.Instance) anyerror!void {
        return try ShadowAnimationImpl.call_cancel(instance);
    }

    pub fn call_finish(instance: *runtime.Instance) anyerror!void {
        return try ShadowAnimationImpl.call_finish(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ShadowAnimationImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ShadowAnimationImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
