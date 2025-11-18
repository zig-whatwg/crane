//! Generated from: css-transitions-2.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSTransitionImpl = @import("../impls/CSSTransition.zig");
const Animation = @import("Animation.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        CSSTransitionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSTransitionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_id(state);
    }

    pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CSSTransitionImpl.set_id(state, value);
    }

    pub fn get_effect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_effect(state);
    }

    pub fn set_effect(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSTransitionImpl.set_effect(state, value);
    }

    pub fn get_timeline(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_timeline(state);
    }

    pub fn set_timeline(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSTransitionImpl.set_timeline(state, value);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_startTime(state);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSTransitionImpl.set_startTime(state, value);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_currentTime(state);
    }

    pub fn set_currentTime(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSTransitionImpl.set_currentTime(state, value);
    }

    pub fn get_playbackRate(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_playbackRate(state);
    }

    pub fn set_playbackRate(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        CSSTransitionImpl.set_playbackRate(state, value);
    }

    pub fn get_playState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_playState(state);
    }

    pub fn get_replaceState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_replaceState(state);
    }

    pub fn get_pending(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_pending(state);
    }

    pub fn get_ready(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_ready(state);
    }

    pub fn get_finished(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_finished(state);
    }

    pub fn get_onfinish(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_onfinish(state);
    }

    pub fn set_onfinish(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSTransitionImpl.set_onfinish(state, value);
    }

    pub fn get_oncancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_oncancel(state);
    }

    pub fn set_oncancel(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSTransitionImpl.set_oncancel(state, value);
    }

    pub fn get_onremove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_onremove(state);
    }

    pub fn set_onremove(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSTransitionImpl.set_onremove(state, value);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_startTime(state);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSTransitionImpl.set_startTime(state, value);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_currentTime(state);
    }

    pub fn set_currentTime(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSTransitionImpl.set_currentTime(state, value);
    }

    pub fn get_trigger(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_trigger(state);
    }

    pub fn set_trigger(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSTransitionImpl.set_trigger(state, value);
    }

    pub fn get_rangeStart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_rangeStart(state);
    }

    pub fn set_rangeStart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSTransitionImpl.set_rangeStart(state, value);
    }

    pub fn get_rangeEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_rangeEnd(state);
    }

    pub fn set_rangeEnd(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSTransitionImpl.set_rangeEnd(state, value);
    }

    pub fn get_overallProgress(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_overallProgress(state);
    }

    pub fn get_transitionProperty(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.get_transitionProperty(state);
    }

    pub fn call_updatePlaybackRate(instance: *runtime.Instance, playbackRate: f64) anyopaque {
        const state = instance.getState(State);
        
        return CSSTransitionImpl.call_updatePlaybackRate(state, playbackRate);
    }

    pub fn call_reverse(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.call_reverse(state);
    }

    pub fn call_persist(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.call_persist(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSTransitionImpl.call_when(state, type_, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_commitStyles(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return CSSTransitionImpl.call_commitStyles(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return CSSTransitionImpl.call_dispatchEvent(state, event);
    }

    pub fn call_pause(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.call_pause(state);
    }

    pub fn call_play(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.call_play(state);
    }

    pub fn call_cancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.call_cancel(state);
    }

    pub fn call_finish(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSTransitionImpl.call_finish(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSTransitionImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CSSTransitionImpl.call_removeEventListener(state, type_, callback, options);
    }

};
