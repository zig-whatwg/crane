//! Generated from: media-playback-quality.idl
//! Generated at: 2025-11-23T16:59:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VideoPlaybackQualityImpl = @import("impls").VideoPlaybackQuality;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;

pub const VideoPlaybackQuality = struct {
    pub const Meta = struct {
        pub const name = "VideoPlaybackQuality";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "creationTime", "get_creationTime", null },
            .{ "droppedVideoFrames", "get_droppedVideoFrames", null },
            .{ "totalVideoFrames", "get_totalVideoFrames", null },
            .{ "corruptedVideoFrames", "get_corruptedVideoFrames", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "creationTime", "get_creationTime", null },
            .{ "droppedVideoFrames", "get_droppedVideoFrames", null },
            .{ "totalVideoFrames", "get_totalVideoFrames", null },
            .{ "corruptedVideoFrames", "get_corruptedVideoFrames", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            creationTime: DOMHighResTimeStamp = undefined,
            droppedVideoFrames: u32 = undefined,
            totalVideoFrames: u32 = undefined,
            corruptedVideoFrames: u32 = undefined,
            _internal: ?*VideoPlaybackQualityImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_corruptedVideoFrames = &get_corruptedVideoFrames,
        .get_creationTime = &get_creationTime,
        .get_droppedVideoFrames = &get_droppedVideoFrames,
        .get_totalVideoFrames = &get_totalVideoFrames,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return VideoPlaybackQualityImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VideoPlaybackQualityImpl.deinit(instance);
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
