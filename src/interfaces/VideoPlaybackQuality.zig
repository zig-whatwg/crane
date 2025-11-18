//! Generated from: media-playback-quality.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VideoPlaybackQualityImpl = @import("../impls/VideoPlaybackQuality.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        VideoPlaybackQualityImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        VideoPlaybackQualityImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_creationTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoPlaybackQualityImpl.get_creationTime(state);
    }

    pub fn get_droppedVideoFrames(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return VideoPlaybackQualityImpl.get_droppedVideoFrames(state);
    }

    pub fn get_totalVideoFrames(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return VideoPlaybackQualityImpl.get_totalVideoFrames(state);
    }

    pub fn get_corruptedVideoFrames(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return VideoPlaybackQualityImpl.get_corruptedVideoFrames(state);
    }

};
