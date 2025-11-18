//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasImageDataImpl = @import("impls").CanvasImageData;
const ImageDataSettings = @import("dictionaries").ImageDataSettings;
const ImageData = @import("interfaces").ImageData;

pub const CanvasImageData = struct {
    pub const Meta = struct {
        pub const name = "CanvasImageData";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CanvasImageData, .{
        .deinit_fn = &deinit_wrapper,

        .call_createImageData = &call_createImageData,
        .call_getImageData = &call_getImageData,
        .call_putImageData = &call_putImageData,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CanvasImageDataImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasImageDataImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getImageData(instance: *runtime.Instance, sx: i32, sy: i32, sw: i32, sh: i32, settings: ImageDataSettings) anyerror!ImageData {
        // [EnforceRange] on sx
        if (!runtime.isInRange(sx)) return error.TypeError;
        // [EnforceRange] on sy
        if (!runtime.isInRange(sy)) return error.TypeError;
        // [EnforceRange] on sw
        if (!runtime.isInRange(sw)) return error.TypeError;
        // [EnforceRange] on sh
        if (!runtime.isInRange(sh)) return error.TypeError;
        
        return try CanvasImageDataImpl.call_getImageData(instance, sx, sy, sw, sh, settings);
    }

    /// Arguments for createImageData (WebIDL overloading)
    pub const CreateImageDataArgs = union(enum) {
        /// createImageData(sw, sh, settings)
        long_long_ImageDataSettings: struct {
            sw: i32,
            sh: i32,
            settings: ImageDataSettings,
        },
        /// createImageData(imageData)
        ImageData: ImageData,
    };

    pub fn call_createImageData(instance: *runtime.Instance, args: CreateImageDataArgs) anyerror!ImageData {
        switch (args) {
            .long_long_ImageDataSettings => |a| return try CanvasImageDataImpl.long_long_ImageDataSettings(instance, a.sw, a.sh, a.settings),
            .ImageData => |arg| return try CanvasImageDataImpl.ImageData(instance, arg),
        }
    }

    /// Arguments for putImageData (WebIDL overloading)
    pub const PutImageDataArgs = union(enum) {
        /// putImageData(imageData, dx, dy)
        ImageData_long_long: struct {
            imageData: ImageData,
            dx: i32,
            dy: i32,
        },
        /// putImageData(imageData, dx, dy, dirtyX, dirtyY, dirtyWidth, dirtyHeight)
        ImageData_long_long_long_long_long_long: struct {
            imageData: ImageData,
            dx: i32,
            dy: i32,
            dirtyX: i32,
            dirtyY: i32,
            dirtyWidth: i32,
            dirtyHeight: i32,
        },
    };

    pub fn call_putImageData(instance: *runtime.Instance, args: PutImageDataArgs) anyerror!void {
        switch (args) {
            .ImageData_long_long => |a| return try CanvasImageDataImpl.ImageData_long_long(instance, a.imageData, a.dx, a.dy),
            .ImageData_long_long_long_long_long_long => |a| return try CanvasImageDataImpl.ImageData_long_long_long_long_long_long(instance, a.imageData, a.dx, a.dy, a.dirtyX, a.dirtyY, a.dirtyWidth, a.dirtyHeight),
        }
    }

};
