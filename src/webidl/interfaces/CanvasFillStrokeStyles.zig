//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasFillStrokeStylesImpl = @import("impls").CanvasFillStrokeStyles;
const (DOMString or CanvasGradient or CanvasPattern) = @import("interfaces").(DOMString or CanvasGradient or CanvasPattern);
const CanvasGradient = @import("interfaces").CanvasGradient;
const CanvasImageSource = @import("typedefs").CanvasImageSource;
const CanvasPattern = @import("interfaces").CanvasPattern;

pub const CanvasFillStrokeStyles = struct {
    pub const Meta = struct {
        pub const name = "CanvasFillStrokeStyles";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            strokeStyle: (DOMString or CanvasGradient or CanvasPattern) = undefined,
            fillStyle: (DOMString or CanvasGradient or CanvasPattern) = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CanvasFillStrokeStyles, .{
        .deinit_fn = &deinit_wrapper,

        .get_fillStyle = &get_fillStyle,
        .get_strokeStyle = &get_strokeStyle,

        .set_fillStyle = &set_fillStyle,
        .set_strokeStyle = &set_strokeStyle,

        .call_createConicGradient = &call_createConicGradient,
        .call_createLinearGradient = &call_createLinearGradient,
        .call_createPattern = &call_createPattern,
        .call_createRadialGradient = &call_createRadialGradient,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CanvasFillStrokeStylesImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasFillStrokeStylesImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_strokeStyle(instance: *runtime.Instance) anyerror!anyopaque {
        return try CanvasFillStrokeStylesImpl.get_strokeStyle(instance);
    }

    pub fn set_strokeStyle(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CanvasFillStrokeStylesImpl.set_strokeStyle(instance, value);
    }

    pub fn get_fillStyle(instance: *runtime.Instance) anyerror!anyopaque {
        return try CanvasFillStrokeStylesImpl.get_fillStyle(instance);
    }

    pub fn set_fillStyle(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try CanvasFillStrokeStylesImpl.set_fillStyle(instance, value);
    }

    pub fn call_createLinearGradient(instance: *runtime.Instance, x0: f64, y0: f64, x1: f64, y1: f64) anyerror!CanvasGradient {
        
        return try CanvasFillStrokeStylesImpl.call_createLinearGradient(instance, x0, y0, x1, y1);
    }

    pub fn call_createPattern(instance: *runtime.Instance, image: CanvasImageSource, repetition: DOMString) anyerror!anyopaque {
        
        return try CanvasFillStrokeStylesImpl.call_createPattern(instance, image, repetition);
    }

    pub fn call_createConicGradient(instance: *runtime.Instance, startAngle: f64, x: f64, y: f64) anyerror!CanvasGradient {
        
        return try CanvasFillStrokeStylesImpl.call_createConicGradient(instance, startAngle, x, y);
    }

    pub fn call_createRadialGradient(instance: *runtime.Instance, x0: f64, y0: f64, r0: f64, x1: f64, y1: f64, r1: f64) anyerror!CanvasGradient {
        
        return try CanvasFillStrokeStylesImpl.call_createRadialGradient(instance, x0, y0, r0, x1, y1, r1);
    }

};
