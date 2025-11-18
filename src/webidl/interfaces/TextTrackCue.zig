//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextTrackCueImpl = @import("impls").TextTrackCue;
const EventTarget = @import("interfaces").EventTarget;
const EventHandler = @import("typedefs").EventHandler;
const TextTrack = @import("interfaces").TextTrack;

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
        
        // Initialize the instance (Impl receives full instance)
        TextTrackCueImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextTrackCueImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!anyopaque {
        return try TextTrackCueImpl.get_track(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try TextTrackCueImpl.get_id(instance);
    }

    pub fn set_id(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try TextTrackCueImpl.set_id(instance, value);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!f64 {
        return try TextTrackCueImpl.get_startTime(instance);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: f64) anyerror!void {
        try TextTrackCueImpl.set_startTime(instance, value);
    }

    pub fn get_endTime(instance: *runtime.Instance) anyerror!f64 {
        return try TextTrackCueImpl.get_endTime(instance);
    }

    pub fn set_endTime(instance: *runtime.Instance, value: f64) anyerror!void {
        try TextTrackCueImpl.set_endTime(instance, value);
    }

    pub fn get_pauseOnExit(instance: *runtime.Instance) anyerror!bool {
        return try TextTrackCueImpl.get_pauseOnExit(instance);
    }

    pub fn set_pauseOnExit(instance: *runtime.Instance, value: bool) anyerror!void {
        try TextTrackCueImpl.set_pauseOnExit(instance, value);
    }

    pub fn get_onenter(instance: *runtime.Instance) anyerror!EventHandler {
        return try TextTrackCueImpl.get_onenter(instance);
    }

    pub fn set_onenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try TextTrackCueImpl.set_onenter(instance, value);
    }

    pub fn get_onexit(instance: *runtime.Instance) anyerror!EventHandler {
        return try TextTrackCueImpl.get_onexit(instance);
    }

    pub fn set_onexit(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try TextTrackCueImpl.set_onexit(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try TextTrackCueImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try TextTrackCueImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try TextTrackCueImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try TextTrackCueImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
