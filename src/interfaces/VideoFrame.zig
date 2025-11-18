//! Generated from: webcodecs.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VideoFrameImpl = @import("../impls/VideoFrame.zig");

pub const VideoFrame = struct {
    pub const Meta = struct {
        pub const name = "VideoFrame";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "Serializable" },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            format: ?VideoPixelFormat = null,
            codedWidth: u32 = undefined,
            codedHeight: u32 = undefined,
            codedRect: ?DOMRectReadOnly = null,
            visibleRect: ?DOMRectReadOnly = null,
            rotation: f64 = undefined,
            flip: bool = undefined,
            displayWidth: u32 = undefined,
            displayHeight: u32 = undefined,
            duration: ?u64 = null,
            timestamp: i64 = undefined,
            colorSpace: VideoColorSpace = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(VideoFrame, .{
        .deinit_fn = &deinit_wrapper,

        .get_codedHeight = &get_codedHeight,
        .get_codedRect = &get_codedRect,
        .get_codedWidth = &get_codedWidth,
        .get_colorSpace = &get_colorSpace,
        .get_displayHeight = &get_displayHeight,
        .get_displayWidth = &get_displayWidth,
        .get_duration = &get_duration,
        .get_flip = &get_flip,
        .get_format = &get_format,
        .get_rotation = &get_rotation,
        .get_timestamp = &get_timestamp,
        .get_visibleRect = &get_visibleRect,

        .call_allocationSize = &call_allocationSize,
        .call_clone = &call_clone,
        .call_close = &call_close,
        .call_copyTo = &call_copyTo,
        .call_metadata = &call_metadata,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        VideoFrameImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        VideoFrameImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, image: anyopaque, init: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try VideoFrameImpl.constructor(state, image, init);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, data: anyopaque, init: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try VideoFrameImpl.constructor(state, data, init);
        
        return instance;
    }

    pub fn get_format(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoFrameImpl.get_format(state);
    }

    pub fn get_codedWidth(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return VideoFrameImpl.get_codedWidth(state);
    }

    pub fn get_codedHeight(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return VideoFrameImpl.get_codedHeight(state);
    }

    pub fn get_codedRect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoFrameImpl.get_codedRect(state);
    }

    pub fn get_visibleRect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoFrameImpl.get_visibleRect(state);
    }

    pub fn get_rotation(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VideoFrameImpl.get_rotation(state);
    }

    pub fn get_flip(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return VideoFrameImpl.get_flip(state);
    }

    pub fn get_displayWidth(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return VideoFrameImpl.get_displayWidth(state);
    }

    pub fn get_displayHeight(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return VideoFrameImpl.get_displayHeight(state);
    }

    pub fn get_duration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoFrameImpl.get_duration(state);
    }

    pub fn get_timestamp(instance: *runtime.Instance) i64 {
        const state = instance.getState(State);
        return VideoFrameImpl.get_timestamp(state);
    }

    pub fn get_colorSpace(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoFrameImpl.get_colorSpace(state);
    }

    pub fn call_allocationSize(instance: *runtime.Instance, options: anyopaque) u32 {
        const state = instance.getState(State);
        
        return VideoFrameImpl.call_allocationSize(state, options);
    }

    pub fn call_copyTo(instance: *runtime.Instance, destination: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return VideoFrameImpl.call_copyTo(state, destination, options);
    }

    pub fn call_clone(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoFrameImpl.call_clone(state);
    }

    pub fn call_metadata(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoFrameImpl.call_metadata(state);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoFrameImpl.call_close(state);
    }

};
