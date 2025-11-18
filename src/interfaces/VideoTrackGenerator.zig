//! Generated from: mediacapture-transform.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VideoTrackGeneratorImpl = @import("../impls/VideoTrackGenerator.zig");

pub const VideoTrackGenerator = struct {
    pub const Meta = struct {
        pub const name = "VideoTrackGenerator";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "DedicatedWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .DedicatedWorker = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            writable: WritableStream = undefined,
            muted: bool = undefined,
            track: MediaStreamTrack = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(VideoTrackGenerator, .{
        .deinit_fn = &deinit_wrapper,

        .get_muted = &get_muted,
        .get_track = &get_track,
        .get_writable = &get_writable,

        .set_muted = &set_muted,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        VideoTrackGeneratorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        VideoTrackGeneratorImpl.deinit(state);
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
        try VideoTrackGeneratorImpl.constructor(state);
        
        return instance;
    }

    pub fn get_writable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoTrackGeneratorImpl.get_writable(state);
    }

    pub fn get_muted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return VideoTrackGeneratorImpl.get_muted(state);
    }

    pub fn set_muted(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        VideoTrackGeneratorImpl.set_muted(state, value);
    }

    pub fn get_track(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoTrackGeneratorImpl.get_track(state);
    }

};
