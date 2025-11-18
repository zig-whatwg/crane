//! Generated from: image-capture.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageCaptureImpl = @import("../impls/ImageCapture.zig");

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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ImageCaptureImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ImageCaptureImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, videoTrack: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try ImageCaptureImpl.constructor(state, videoTrack);
        
        return instance;
    }

    pub fn get_track(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ImageCaptureImpl.get_track(state);
    }

    pub fn call_getPhotoCapabilities(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ImageCaptureImpl.call_getPhotoCapabilities(state);
    }

    pub fn call_grabFrame(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ImageCaptureImpl.call_grabFrame(state);
    }

    pub fn call_getPhotoSettings(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ImageCaptureImpl.call_getPhotoSettings(state);
    }

    pub fn call_takePhoto(instance: *runtime.Instance, photoSettings: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ImageCaptureImpl.call_takePhoto(state, photoSettings);
    }

};
