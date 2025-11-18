//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasFillStrokeStylesImpl = @import("../impls/CanvasFillStrokeStyles.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        CanvasFillStrokeStylesImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CanvasFillStrokeStylesImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_strokeStyle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasFillStrokeStylesImpl.get_strokeStyle(state);
    }

    pub fn set_strokeStyle(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasFillStrokeStylesImpl.set_strokeStyle(state, value);
    }

    pub fn get_fillStyle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasFillStrokeStylesImpl.get_fillStyle(state);
    }

    pub fn set_fillStyle(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasFillStrokeStylesImpl.set_fillStyle(state, value);
    }

    pub fn call_createLinearGradient(instance: *runtime.Instance, x0: f64, y0: f64, x1: f64, y1: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasFillStrokeStylesImpl.call_createLinearGradient(state, x0, y0, x1, y1);
    }

    pub fn call_createPattern(instance: *runtime.Instance, image: anyopaque, repetition: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return CanvasFillStrokeStylesImpl.call_createPattern(state, image, repetition);
    }

    pub fn call_createConicGradient(instance: *runtime.Instance, startAngle: f64, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasFillStrokeStylesImpl.call_createConicGradient(state, startAngle, x, y);
    }

    pub fn call_createRadialGradient(instance: *runtime.Instance, x0: f64, y0: f64, r0: f64, x1: f64, y1: f64, r1: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasFillStrokeStylesImpl.call_createRadialGradient(state, x0, y0, r0, x1, y1, r1);
    }

};
