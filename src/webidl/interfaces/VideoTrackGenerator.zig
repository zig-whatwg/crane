//! Generated from: mediacapture-transform.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VideoTrackGeneratorImpl = @import("impls").VideoTrackGenerator;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const WritableStream = @import("interfaces").WritableStream;

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
        
        // Initialize the instance (Impl receives full instance)
        VideoTrackGeneratorImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VideoTrackGeneratorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try VideoTrackGeneratorImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!WritableStream {
        return try VideoTrackGeneratorImpl.get_writable(instance);
    }

    pub fn get_muted(instance: *runtime.Instance) anyerror!bool {
        return try VideoTrackGeneratorImpl.get_muted(instance);
    }

    pub fn set_muted(instance: *runtime.Instance, value: bool) anyerror!void {
        try VideoTrackGeneratorImpl.set_muted(instance, value);
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!MediaStreamTrack {
        return try VideoTrackGeneratorImpl.get_track(instance);
    }

};
