//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageDataImpl = @import("../impls/ImageData.zig");

pub const ImageData = struct {
    pub const Meta = struct {
        pub const name = "ImageData";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            width: u32 = undefined,
            height: u32 = undefined,
            data: ImageDataArray = undefined,
            pixelFormat: ImageDataPixelFormat = undefined,
            colorSpace: PredefinedColorSpace = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ImageData, .{
        .deinit_fn = &deinit_wrapper,

        .get_colorSpace = &get_colorSpace,
        .get_data = &get_data,
        .get_height = &get_height,
        .get_pixelFormat = &get_pixelFormat,
        .get_width = &get_width,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ImageDataImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ImageDataImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, sw: u32, sh: u32, settings: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try ImageDataImpl.constructor(state, sw, sh, settings);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, data: anyopaque, sw: u32, sh: u32, settings: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try ImageDataImpl.constructor(state, data, sw, sh, settings);
        
        return instance;
    }

    pub fn get_width(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return ImageDataImpl.get_width(state);
    }

    pub fn get_height(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return ImageDataImpl.get_height(state);
    }

    pub fn get_data(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ImageDataImpl.get_data(state);
    }

    pub fn get_pixelFormat(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ImageDataImpl.get_pixelFormat(state);
    }

    pub fn get_colorSpace(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ImageDataImpl.get_colorSpace(state);
    }

};
