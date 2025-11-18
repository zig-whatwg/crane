//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasImageSmoothingImpl = @import("../impls/CanvasImageSmoothing.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        CanvasImageSmoothingImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CanvasImageSmoothingImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_imageSmoothingEnabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return CanvasImageSmoothingImpl.get_imageSmoothingEnabled(state);
    }

    pub fn set_imageSmoothingEnabled(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        CanvasImageSmoothingImpl.set_imageSmoothingEnabled(state, value);
    }

    pub fn get_imageSmoothingQuality(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasImageSmoothingImpl.get_imageSmoothingQuality(state);
    }

    pub fn set_imageSmoothingQuality(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasImageSmoothingImpl.set_imageSmoothingQuality(state, value);
    }

};
