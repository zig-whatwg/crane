//! Generated from: media-playback-quality.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VideoPlaybackQualityImpl = @import("impls").VideoPlaybackQuality;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;

pub const VideoPlaybackQuality = struct {
    pub const Meta = struct {
        pub const name = "VideoPlaybackQuality";
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
            creationTime: DOMHighResTimeStamp = undefined,
            droppedVideoFrames: u32 = undefined,
            totalVideoFrames: u32 = undefined,
            corruptedVideoFrames: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(VideoPlaybackQuality, .{
        .deinit_fn = &deinit_wrapper,

        .get_corruptedVideoFrames = &get_corruptedVideoFrames,
        .get_creationTime = &get_creationTime,
        .get_droppedVideoFrames = &get_droppedVideoFrames,
        .get_totalVideoFrames = &get_totalVideoFrames,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        VideoPlaybackQualityImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VideoPlaybackQualityImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_creationTime(instance: *runtime.Instance) anyerror!DOMHighResTimeStamp {
        return try VideoPlaybackQualityImpl.get_creationTime(instance);
    }

    pub fn get_droppedVideoFrames(instance: *runtime.Instance) anyerror!u32 {
        return try VideoPlaybackQualityImpl.get_droppedVideoFrames(instance);
    }

    pub fn get_totalVideoFrames(instance: *runtime.Instance) anyerror!u32 {
        return try VideoPlaybackQualityImpl.get_totalVideoFrames(instance);
    }

    pub fn get_corruptedVideoFrames(instance: *runtime.Instance) anyerror!u32 {
        return try VideoPlaybackQualityImpl.get_corruptedVideoFrames(instance);
    }

};
