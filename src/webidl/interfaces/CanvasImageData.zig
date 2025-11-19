//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:02Z
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
        return CanvasImageDataImpl.init(allocator, State, &vtable);
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

    pub fn call_createImageData(instance: *runtime.Instance, sw: i32, sh: i32, settings: ImageDataSettings) anyerror!ImageData {
        // [EnforceRange] on sw
        if (!runtime.isInRange(sw)) return error.TypeError;
        // [EnforceRange] on sh
        if (!runtime.isInRange(sh)) return error.TypeError;
        
        return try CanvasImageDataImpl.call_createImageData(instance, sw, sh, settings);
    }

    pub fn call_putImageData(instance: *runtime.Instance, imageData: ImageData, dx: i32, dy: i32) anyerror!void {
        // [EnforceRange] on dx
        if (!runtime.isInRange(dx)) return error.TypeError;
        // [EnforceRange] on dy
        if (!runtime.isInRange(dy)) return error.TypeError;
        
        return try CanvasImageDataImpl.call_putImageData(instance, imageData, dx, dy);
    }

};
