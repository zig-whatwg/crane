//! Generated from: mediacapture-streams.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaStreamImpl = @import("../impls/MediaStream.zig");
const EventTarget = @import("EventTarget.zig");

pub const MediaStream = struct {
    pub const Meta = struct {
        pub const name = "MediaStream";
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
            active: bool = undefined,
            onaddtrack: EventHandler = undefined,
            onremovetrack: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaStream, .{
        .deinit_fn = &deinit_wrapper,

        .get_active = &get_active,
        .get_id = &get_id,
        .get_onaddtrack = &get_onaddtrack,
        .get_onremovetrack = &get_onremovetrack,

        .set_onaddtrack = &set_onaddtrack,
        .set_onremovetrack = &set_onremovetrack,

        .call_addEventListener = &call_addEventListener,
        .call_addTrack = &call_addTrack,
        .call_clone = &call_clone,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getAudioTracks = &call_getAudioTracks,
        .call_getTrackById = &call_getTrackById,
        .call_getTracks = &call_getTracks,
        .call_getVideoTracks = &call_getVideoTracks,
        .call_removeEventListener = &call_removeEventListener,
        .call_removeTrack = &call_removeTrack,
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
        MediaStreamImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MediaStreamImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try MediaStreamImpl.constructor(state);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, stream: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try MediaStreamImpl.constructor(state, stream);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, tracks: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try MediaStreamImpl.constructor(state, tracks);
        
        return instance;
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MediaStreamImpl.get_id(state);
    }

    pub fn get_active(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MediaStreamImpl.get_active(state);
    }

    pub fn get_onaddtrack(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamImpl.get_onaddtrack(state);
    }

    pub fn set_onaddtrack(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaStreamImpl.set_onaddtrack(state, value);
    }

    pub fn get_onremovetrack(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamImpl.get_onremovetrack(state);
    }

    pub fn set_onremovetrack(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaStreamImpl.set_onremovetrack(state, value);
    }

    pub fn call_getAudioTracks(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamImpl.call_getAudioTracks(state);
    }

    pub fn call_getVideoTracks(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamImpl.call_getVideoTracks(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaStreamImpl.call_when(state, type_, options);
    }

    pub fn call_clone(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamImpl.call_clone(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return MediaStreamImpl.call_dispatchEvent(state, event);
    }

    pub fn call_getTrackById(instance: *runtime.Instance, trackId: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return MediaStreamImpl.call_getTrackById(state, trackId);
    }

    pub fn call_addTrack(instance: *runtime.Instance, track: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaStreamImpl.call_addTrack(state, track);
    }

    pub fn call_removeTrack(instance: *runtime.Instance, track: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaStreamImpl.call_removeTrack(state, track);
    }

    pub fn call_getTracks(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamImpl.call_getTracks(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaStreamImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaStreamImpl.call_removeEventListener(state, type_, callback, options);
    }

};
