//! Generated from: mediasession.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaSessionImpl = @import("../impls/MediaSession.zig");

pub const MediaSession = struct {
    pub const Meta = struct {
        pub const name = "MediaSession";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            metadata: ?MediaMetadata = null,
            playbackState: MediaSessionPlaybackState = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaSession, .{
        .deinit_fn = &deinit_wrapper,

        .get_metadata = &get_metadata,
        .get_playbackState = &get_playbackState,

        .set_metadata = &set_metadata,
        .set_playbackState = &set_playbackState,

        .call_setActionHandler = &call_setActionHandler,
        .call_setCameraActive = &call_setCameraActive,
        .call_setMicrophoneActive = &call_setMicrophoneActive,
        .call_setPositionState = &call_setPositionState,
        .call_setScreenshareActive = &call_setScreenshareActive,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MediaSessionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MediaSessionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_metadata(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaSessionImpl.get_metadata(state);
    }

    pub fn set_metadata(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaSessionImpl.set_metadata(state, value);
    }

    pub fn get_playbackState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaSessionImpl.get_playbackState(state);
    }

    pub fn set_playbackState(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaSessionImpl.set_playbackState(state, value);
    }

    pub fn call_setMicrophoneActive(instance: *runtime.Instance, active: bool) anyopaque {
        const state = instance.getState(State);
        
        return MediaSessionImpl.call_setMicrophoneActive(state, active);
    }

    pub fn call_setCameraActive(instance: *runtime.Instance, active: bool) anyopaque {
        const state = instance.getState(State);
        
        return MediaSessionImpl.call_setCameraActive(state, active);
    }

    pub fn call_setPositionState(instance: *runtime.Instance, state: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaSessionImpl.call_setPositionState(state, state);
    }

    pub fn call_setScreenshareActive(instance: *runtime.Instance, active: bool) anyopaque {
        const state = instance.getState(State);
        
        return MediaSessionImpl.call_setScreenshareActive(state, active);
    }

    pub fn call_setActionHandler(instance: *runtime.Instance, action: anyopaque, handler: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaSessionImpl.call_setActionHandler(state, action, handler);
    }

};
