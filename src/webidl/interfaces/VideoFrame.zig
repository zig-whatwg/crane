//! Generated from: webcodecs.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VideoFrameImpl = @import("impls").VideoFrame;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const VideoFrameMetadata = @import("dictionaries").VideoFrameMetadata;
const VideoFrameInit = @import("dictionaries").VideoFrameInit;
const VideoFrameCopyToOptions = @import("dictionaries").VideoFrameCopyToOptions;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const VideoColorSpace = @import("interfaces").VideoColorSpace;
const Promise<sequence<PlaneLayout>> = @import("interfaces").Promise<sequence<PlaneLayout>>;
const CanvasImageSource = @import("typedefs").CanvasImageSource;
const VideoFrameBufferInit = @import("dictionaries").VideoFrameBufferInit;
const unsigned long long = @import("interfaces").unsigned long long;
const VideoPixelFormat = @import("enums").VideoPixelFormat;

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
        
        // Initialize the instance (Impl receives full instance)
        VideoFrameImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VideoFrameImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, image: CanvasImageSource, init: VideoFrameInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try VideoFrameImpl.constructor(instance, image, init);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, data: AllowSharedBufferSource, init: VideoFrameBufferInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try VideoFrameImpl.constructor(instance, data, init);
        
        return instance;
    }

    pub fn get_format(instance: *runtime.Instance) anyerror!anyopaque {
        return try VideoFrameImpl.get_format(instance);
    }

    pub fn get_codedWidth(instance: *runtime.Instance) anyerror!u32 {
        return try VideoFrameImpl.get_codedWidth(instance);
    }

    pub fn get_codedHeight(instance: *runtime.Instance) anyerror!u32 {
        return try VideoFrameImpl.get_codedHeight(instance);
    }

    pub fn get_codedRect(instance: *runtime.Instance) anyerror!anyopaque {
        return try VideoFrameImpl.get_codedRect(instance);
    }

    pub fn get_visibleRect(instance: *runtime.Instance) anyerror!anyopaque {
        return try VideoFrameImpl.get_visibleRect(instance);
    }

    pub fn get_rotation(instance: *runtime.Instance) anyerror!f64 {
        return try VideoFrameImpl.get_rotation(instance);
    }

    pub fn get_flip(instance: *runtime.Instance) anyerror!bool {
        return try VideoFrameImpl.get_flip(instance);
    }

    pub fn get_displayWidth(instance: *runtime.Instance) anyerror!u32 {
        return try VideoFrameImpl.get_displayWidth(instance);
    }

    pub fn get_displayHeight(instance: *runtime.Instance) anyerror!u32 {
        return try VideoFrameImpl.get_displayHeight(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!anyopaque {
        return try VideoFrameImpl.get_duration(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!i64 {
        return try VideoFrameImpl.get_timestamp(instance);
    }

    pub fn get_colorSpace(instance: *runtime.Instance) anyerror!VideoColorSpace {
        return try VideoFrameImpl.get_colorSpace(instance);
    }

    pub fn call_allocationSize(instance: *runtime.Instance, options: VideoFrameCopyToOptions) anyerror!u32 {
        
        return try VideoFrameImpl.call_allocationSize(instance, options);
    }

    pub fn call_copyTo(instance: *runtime.Instance, destination: AllowSharedBufferSource, options: VideoFrameCopyToOptions) anyerror!anyopaque {
        
        return try VideoFrameImpl.call_copyTo(instance, destination, options);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!VideoFrame {
        return try VideoFrameImpl.call_clone(instance);
    }

    pub fn call_metadata(instance: *runtime.Instance) anyerror!VideoFrameMetadata {
        return try VideoFrameImpl.call_metadata(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try VideoFrameImpl.call_close(instance);
    }

};
