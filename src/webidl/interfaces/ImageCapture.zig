//! Generated from: image-capture.idl
//! Generated at: 2025-11-23T19:17:36Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageCaptureImpl = @import("impls").ImageCapture;
const PhotoSettings = @import("dictionaries").PhotoSettings;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const PhotoCapabilities = @import("dictionaries").PhotoCapabilities;
const Blob = @import("interfaces").Blob;
const ImageBitmap = @import("interfaces").ImageBitmap;

pub const ImageCapture = struct {
    pub const Meta = struct {
        pub const name = "ImageCapture";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "track", "get_track", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "takePhoto", "call_takePhoto", 0 },
            .{ "getPhotoCapabilities", "call_getPhotoCapabilities", 0 },
            .{ "getPhotoSettings", "call_getPhotoSettings", 0 },
            .{ "grabFrame", "call_grabFrame", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "takePhoto",
            "getPhotoCapabilities",
            "getPhotoSettings",
            "grabFrame",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "track", "get_track", null },
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
            track: MediaStreamTrack = undefined,
            _internal: ?*ImageCaptureImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_track = &get_track,

        .call_getPhotoCapabilities = &call_getPhotoCapabilities,
        .call_getPhotoSettings = &call_getPhotoSettings,
        .call_grabFrame = &call_grabFrame,
        .call_takePhoto = &call_takePhoto,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ImageCaptureImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ImageCaptureImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, videoTrack: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ImageCaptureImpl.call_constructor(allocator, ctx, videoTrack);
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ImageCaptureImpl.get_track(instance);
    }

    pub fn call_getPhotoCapabilities(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ImageCaptureImpl.call_getPhotoCapabilities(instance);
    }

    pub fn call_grabFrame(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ImageCaptureImpl.call_grabFrame(instance);
    }

    pub fn call_getPhotoSettings(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ImageCaptureImpl.call_getPhotoSettings(instance);
    }

    pub fn call_takePhoto(instance: *runtime.Instance, photoSettings: PhotoSettings) anyerror!*const anyopaque {
        
        return try ImageCaptureImpl.call_takePhoto(instance, photoSettings);
    }

};
