//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextTrackCueImpl = @import("../impls/TextTrackCue.zig");
const EventTarget = @import("EventTarget.zig");

pub const TextTrackCue = struct {
    pub const Meta = struct {
        pub const name = "TextTrackCue";
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
            track: ?TextTrack = null,
            id: runtime.DOMString = undefined,
            startTime: f64 = undefined,
            endTime: f64 = undefined,
            pauseOnExit: bool = undefined,
            onenter: EventHandler = undefined,
            onexit: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TextTrackCue, .{
        .deinit_fn = &deinit_wrapper,

        .get_endTime = &get_endTime,
        .get_id = &get_id,
        .get_onenter = &get_onenter,
        .get_onexit = &get_onexit,
        .get_pauseOnExit = &get_pauseOnExit,
        .get_startTime = &get_startTime,
        .get_track = &get_track,

        .set_endTime = &set_endTime,
        .set_id = &set_id,
        .set_onenter = &set_onenter,
        .set_onexit = &set_onexit,
        .set_pauseOnExit = &set_pauseOnExit,
        .set_startTime = &set_startTime,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
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
        TextTrackCueImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TextTrackCueImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_track(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TextTrackCueImpl.get_track(state);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return TextTrackCueImpl.get_id(state);
    }

    pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        TextTrackCueImpl.set_id(state, value);
    }

    pub fn get_startTime(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TextTrackCueImpl.get_startTime(state);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        TextTrackCueImpl.set_startTime(state, value);
    }

    pub fn get_endTime(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return TextTrackCueImpl.get_endTime(state);
    }

    pub fn set_endTime(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        TextTrackCueImpl.set_endTime(state, value);
    }

    pub fn get_pauseOnExit(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return TextTrackCueImpl.get_pauseOnExit(state);
    }

    pub fn set_pauseOnExit(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        TextTrackCueImpl.set_pauseOnExit(state, value);
    }

    pub fn get_onenter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TextTrackCueImpl.get_onenter(state);
    }

    pub fn set_onenter(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        TextTrackCueImpl.set_onenter(state, value);
    }

    pub fn get_onexit(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TextTrackCueImpl.get_onexit(state);
    }

    pub fn set_onexit(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        TextTrackCueImpl.set_onexit(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return TextTrackCueImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TextTrackCueImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TextTrackCueImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TextTrackCueImpl.call_removeEventListener(state, type_, callback, options);
    }

};
