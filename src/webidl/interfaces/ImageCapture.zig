//! Generated from: image-capture.idl
//! Generated at: 2025-11-19T20:02:02Z
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
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            track: MediaStreamTrack = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ImageCapture, .{
        .deinit_fn = &deinit_wrapper,

        .get_track = &get_track,

        .call_getPhotoCapabilities = &call_getPhotoCapabilities,
        .call_getPhotoSettings = &call_getPhotoSettings,
        .call_grabFrame = &call_grabFrame,
        .call_takePhoto = &call_takePhoto,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return ImageCaptureImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ImageCaptureImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, videoTrack: MediaStreamTrack) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ImageCaptureImpl.constructor(instance, videoTrack);
        
        return instance;
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!MediaStreamTrack {
        return try ImageCaptureImpl.get_track(instance);
    }

    pub fn call_getPhotoCapabilities(instance: *runtime.Instance) anyerror!anyopaque {
        return try ImageCaptureImpl.call_getPhotoCapabilities(instance);
    }

    pub fn call_grabFrame(instance: *runtime.Instance) anyerror!anyopaque {
        return try ImageCaptureImpl.call_grabFrame(instance);
    }

    pub fn call_getPhotoSettings(instance: *runtime.Instance) anyerror!anyopaque {
        return try ImageCaptureImpl.call_getPhotoSettings(instance);
    }

    pub fn call_takePhoto(instance: *runtime.Instance, photoSettings: PhotoSettings) anyerror!anyopaque {
        
        return try ImageCaptureImpl.call_takePhoto(instance, photoSettings);
    }

};
