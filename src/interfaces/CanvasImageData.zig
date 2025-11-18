//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasImageDataImpl = @import("../impls/CanvasImageData.zig");

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
        .call_createImageData = &call_createImageData,
        .call_getImageData = &call_getImageData,
        .call_putImageData = &call_putImageData,
        .call_putImageData = &call_putImageData,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CanvasImageDataImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CanvasImageDataImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getImageData(instance: *runtime.Instance, sx: i32, sy: i32, sw: i32, sh: i32, settings: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CanvasImageDataImpl.call_getImageData(state, sx, sy, sw, sh, settings);
    }

    /// Arguments for createImageData (WebIDL overloading)
    pub const CreateImageDataArgs = union(enum) {
        /// createImageData(sw, sh, settings)
        long_long_ImageDataSettings: struct {
            sw: i32,
            sh: i32,
            settings: anyopaque,
        },
        /// createImageData(imageData)
        ImageData: anyopaque,
    };

    pub fn call_createImageData(instance: *runtime.Instance, args: CreateImageDataArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .long_long_ImageDataSettings => |a| return CanvasImageDataImpl.long_long_ImageDataSettings(state, a.sw, a.sh, a.settings),
            .ImageData => |arg| return CanvasImageDataImpl.ImageData(state, arg),
        }
    }

    /// Arguments for putImageData (WebIDL overloading)
    pub const PutImageDataArgs = union(enum) {
        /// putImageData(imageData, dx, dy)
        ImageData_long_long: struct {
            imageData: anyopaque,
            dx: i32,
            dy: i32,
        },
        /// putImageData(imageData, dx, dy, dirtyX, dirtyY, dirtyWidth, dirtyHeight)
        ImageData_long_long_long_long_long_long: struct {
            imageData: anyopaque,
            dx: i32,
            dy: i32,
            dirtyX: i32,
            dirtyY: i32,
            dirtyWidth: i32,
            dirtyHeight: i32,
        },
    };

    pub fn call_putImageData(instance: *runtime.Instance, args: PutImageDataArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .ImageData_long_long => |a| return CanvasImageDataImpl.ImageData_long_long(state, a.imageData, a.dx, a.dy),
            .ImageData_long_long_long_long_long_long => |a| return CanvasImageDataImpl.ImageData_long_long_long_long_long_long(state, a.imageData, a.dx, a.dy, a.dirtyX, a.dirtyY, a.dirtyWidth, a.dirtyHeight),
        }
    }

};
