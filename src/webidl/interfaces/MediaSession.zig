//! Generated from: mediasession.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaSessionImpl = @import("impls").MediaSession;
const MediaSessionPlaybackState = @import("enums").MediaSessionPlaybackState;
const MediaSessionActionHandler = @import("callbacks").MediaSessionActionHandler;
const MediaSessionAction = @import("enums").MediaSessionAction;
const MediaMetadata = @import("interfaces").MediaMetadata;
const MediaPositionState = @import("dictionaries").MediaPositionState;
const Promise<undefined> = @import("interfaces").Promise<undefined>;

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
        
        // Initialize the instance (Impl receives full instance)
        MediaSessionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaSessionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_metadata(instance: *runtime.Instance) anyerror!anyopaque {
        return try MediaSessionImpl.get_metadata(instance);
    }

    pub fn set_metadata(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try MediaSessionImpl.set_metadata(instance, value);
    }

    pub fn get_playbackState(instance: *runtime.Instance) anyerror!MediaSessionPlaybackState {
        return try MediaSessionImpl.get_playbackState(instance);
    }

    pub fn set_playbackState(instance: *runtime.Instance, value: MediaSessionPlaybackState) anyerror!void {
        try MediaSessionImpl.set_playbackState(instance, value);
    }

    pub fn call_setMicrophoneActive(instance: *runtime.Instance, active: bool) anyerror!anyopaque {
        
        return try MediaSessionImpl.call_setMicrophoneActive(instance, active);
    }

    pub fn call_setCameraActive(instance: *runtime.Instance, active: bool) anyerror!anyopaque {
        
        return try MediaSessionImpl.call_setCameraActive(instance, active);
    }

    pub fn call_setPositionState(instance: *runtime.Instance, state: MediaPositionState) anyerror!void {
        
        return try MediaSessionImpl.call_setPositionState(instance, state);
    }

    pub fn call_setScreenshareActive(instance: *runtime.Instance, active: bool) anyerror!anyopaque {
        
        return try MediaSessionImpl.call_setScreenshareActive(instance, active);
    }

    pub fn call_setActionHandler(instance: *runtime.Instance, action: MediaSessionAction, handler: anyopaque) anyerror!void {
        
        return try MediaSessionImpl.call_setActionHandler(instance, action, handler);
    }

};
