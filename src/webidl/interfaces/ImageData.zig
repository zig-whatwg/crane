//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageDataImpl = @import("impls").ImageData;
const PredefinedColorSpace = @import("enums").PredefinedColorSpace;
const ImageDataArray = @import("typedefs").ImageDataArray;
const ImageDataSettings = @import("dictionaries").ImageDataSettings;
const ImageDataPixelFormat = @import("enums").ImageDataPixelFormat;

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
        
        // Initialize the instance (Impl receives full instance)
        ImageDataImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ImageDataImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, sw: u32, sh: u32, settings: ImageDataSettings) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ImageDataImpl.constructor(instance, sw, sh, settings);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, data: ImageDataArray, sw: u32, sh: u32, settings: ImageDataSettings) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try ImageDataImpl.constructor(instance, data, sw, sh, settings);
        
        return instance;
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
        return try ImageDataImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
        return try ImageDataImpl.get_height(instance);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!ImageDataArray {
        return try ImageDataImpl.get_data(instance);
    }

    pub fn get_pixelFormat(instance: *runtime.Instance) anyerror!ImageDataPixelFormat {
        return try ImageDataImpl.get_pixelFormat(instance);
    }

    pub fn get_colorSpace(instance: *runtime.Instance) anyerror!PredefinedColorSpace {
        return try ImageDataImpl.get_colorSpace(instance);
    }

};
