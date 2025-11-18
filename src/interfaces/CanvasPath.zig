//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasPathImpl = @import("../impls/CanvasPath.zig");

pub const CanvasPath = struct {
    pub const Meta = struct {
        pub const name = "CanvasPath";
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

    pub const vtable = runtime.buildVTable(CanvasPath, .{
        .deinit_fn = &deinit_wrapper,

        .call_arc = &call_arc,
        .call_arcTo = &call_arcTo,
        .call_bezierCurveTo = &call_bezierCurveTo,
        .call_closePath = &call_closePath,
        .call_ellipse = &call_ellipse,
        .call_lineTo = &call_lineTo,
        .call_moveTo = &call_moveTo,
        .call_quadraticCurveTo = &call_quadraticCurveTo,
        .call_rect = &call_rect,
        .call_roundRect = &call_roundRect,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CanvasPathImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CanvasPathImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_lineTo(instance: *runtime.Instance, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasPathImpl.call_lineTo(state, x, y);
    }

    pub fn call_arcTo(instance: *runtime.Instance, x1: f64, y1: f64, x2: f64, y2: f64, radius: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasPathImpl.call_arcTo(state, x1, y1, x2, y2, radius);
    }

    pub fn call_arc(instance: *runtime.Instance, x: f64, y: f64, radius: f64, startAngle: f64, endAngle: f64, counterclockwise: bool) anyopaque {
        const state = instance.getState(State);
        
        return CanvasPathImpl.call_arc(state, x, y, radius, startAngle, endAngle, counterclockwise);
    }

    pub fn call_moveTo(instance: *runtime.Instance, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasPathImpl.call_moveTo(state, x, y);
    }

    pub fn call_quadraticCurveTo(instance: *runtime.Instance, cpx: f64, cpy: f64, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasPathImpl.call_quadraticCurveTo(state, cpx, cpy, x, y);
    }

    pub fn call_bezierCurveTo(instance: *runtime.Instance, cp1x: f64, cp1y: f64, cp2x: f64, cp2y: f64, x: f64, y: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasPathImpl.call_bezierCurveTo(state, cp1x, cp1y, cp2x, cp2y, x, y);
    }

    pub fn call_ellipse(instance: *runtime.Instance, x: f64, y: f64, radiusX: f64, radiusY: f64, rotation: f64, startAngle: f64, endAngle: f64, counterclockwise: bool) anyopaque {
        const state = instance.getState(State);
        
        return CanvasPathImpl.call_ellipse(state, x, y, radiusX, radiusY, rotation, startAngle, endAngle, counterclockwise);
    }

    pub fn call_closePath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasPathImpl.call_closePath(state);
    }

    pub fn call_roundRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64, radii: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CanvasPathImpl.call_roundRect(state, x, y, w, h, radii);
    }

    pub fn call_rect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasPathImpl.call_rect(state, x, y, w, h);
    }

};
