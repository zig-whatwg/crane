//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasImageSmoothingImpl = @import("impls").CanvasImageSmoothing;
const ImageSmoothingQuality = @import("enums").ImageSmoothingQuality;

pub const CanvasImageSmoothing = struct {
    pub const Meta = struct {
        pub const name = "CanvasImageSmoothing";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            imageSmoothingEnabled: bool = undefined,
            imageSmoothingQuality: ImageSmoothingQuality = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CanvasImageSmoothing, .{
        .deinit_fn = &deinit_wrapper,

        .get_imageSmoothingEnabled = &get_imageSmoothingEnabled,
        .get_imageSmoothingQuality = &get_imageSmoothingQuality,

        .set_imageSmoothingEnabled = &set_imageSmoothingEnabled,
        .set_imageSmoothingQuality = &set_imageSmoothingQuality,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CanvasImageSmoothingImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasImageSmoothingImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_imageSmoothingEnabled(instance: *runtime.Instance) anyerror!bool {
        return try CanvasImageSmoothingImpl.get_imageSmoothingEnabled(instance);
    }

    pub fn set_imageSmoothingEnabled(instance: *runtime.Instance, value: bool) anyerror!void {
        try CanvasImageSmoothingImpl.set_imageSmoothingEnabled(instance, value);
    }

    pub fn get_imageSmoothingQuality(instance: *runtime.Instance) anyerror!ImageSmoothingQuality {
        return try CanvasImageSmoothingImpl.get_imageSmoothingQuality(instance);
    }

    pub fn set_imageSmoothingQuality(instance: *runtime.Instance, value: ImageSmoothingQuality) anyerror!void {
        try CanvasImageSmoothingImpl.set_imageSmoothingQuality(instance, value);
    }

};
