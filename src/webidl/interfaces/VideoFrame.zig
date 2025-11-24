//! Generated from: webcodecs.idl
//! Generated at: 2025-11-24T18:47:07Z
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
const CanvasImageSource = @import("typedefs").CanvasImageSource;
const VideoFrameBufferInit = @import("dictionaries").VideoFrameBufferInit;
const VideoPixelFormat = @import("enums").VideoPixelFormat;

pub const VideoFrame = struct {
    pub const Meta = struct {
        pub const name = "VideoFrame";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
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
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "format", "get_format", null },
            .{ "codedWidth", "get_codedWidth", null },
            .{ "codedHeight", "get_codedHeight", null },
            .{ "codedRect", "get_codedRect", null },
            .{ "visibleRect", "get_visibleRect", null },
            .{ "rotation", "get_rotation", null },
            .{ "flip", "get_flip", null },
            .{ "displayWidth", "get_displayWidth", null },
            .{ "displayHeight", "get_displayHeight", null },
            .{ "duration", "get_duration", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "colorSpace", "get_colorSpace", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "metadata", "call_metadata", 0 },
            .{ "allocationSize", "call_allocationSize", 0 },
            .{ "copyTo", "call_copyTo", 1 },
            .{ "clone", "call_clone", 0 },
            .{ "close", "call_close", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "metadata",
            "allocationSize",
            "copyTo",
            "clone",
            "close",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "format", "get_format", null },
            .{ "codedWidth", "get_codedWidth", null },
            .{ "codedHeight", "get_codedHeight", null },
            .{ "codedRect", "get_codedRect", null },
            .{ "visibleRect", "get_visibleRect", null },
            .{ "rotation", "get_rotation", null },
            .{ "flip", "get_flip", null },
            .{ "displayWidth", "get_displayWidth", null },
            .{ "displayHeight", "get_displayHeight", null },
            .{ "duration", "get_duration", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "colorSpace", "get_colorSpace", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            format: ?VideoPixelFormat = null,
            codedWidth: u32 = undefined,
            codedHeight: u32 = undefined,
            codedRect: ?*runtime.Instance = null,
            visibleRect: ?*runtime.Instance = null,
            rotation: f64 = undefined,
            flip: bool = undefined,
            displayWidth: u32 = undefined,
            displayHeight: u32 = undefined,
            duration: ?u64 = null,
            timestamp: i64 = undefined,
            colorSpace: *runtime.Instance = undefined,
            _internal: ?*VideoFrameImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return VideoFrameImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VideoFrameImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, image: CanvasImageSource, init_data: VideoFrameInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try VideoFrameImpl.call_constructor(allocator, ctx, image, init_data);
    }

    pub fn get_format(instance: *runtime.Instance) anyerror!VideoPixelFormat {
        return try VideoFrameImpl.get_format(instance);
    }

    pub fn get_codedWidth(instance: *runtime.Instance) anyerror!u32 {
        return try VideoFrameImpl.get_codedWidth(instance);
    }

    pub fn get_codedHeight(instance: *runtime.Instance) anyerror!u32 {
        return try VideoFrameImpl.get_codedHeight(instance);
    }

    pub fn get_codedRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try VideoFrameImpl.get_codedRect(instance);
    }

    pub fn get_visibleRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
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

    pub fn get_duration(instance: *runtime.Instance) anyerror!u64 {
        return try VideoFrameImpl.get_duration(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!i64 {
        return try VideoFrameImpl.get_timestamp(instance);
    }

    pub fn get_colorSpace(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try VideoFrameImpl.get_colorSpace(instance);
    }

    pub fn call_allocationSize(instance: *runtime.Instance, options: VideoFrameCopyToOptions) anyerror!u32 {
        
        return try VideoFrameImpl.call_allocationSize(instance, options);
    }

    pub fn call_copyTo(instance: *runtime.Instance, destination: AllowSharedBufferSource, options: VideoFrameCopyToOptions) anyerror!*const anyopaque {
        
        return try VideoFrameImpl.call_copyTo(instance, destination, options);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try VideoFrameImpl.call_clone(instance);
    }

    pub fn call_metadata(instance: *runtime.Instance) anyerror!VideoFrameMetadata {
        return try VideoFrameImpl.call_metadata(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try VideoFrameImpl.call_close(instance);
    }

};
