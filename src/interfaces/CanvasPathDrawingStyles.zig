//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasPathDrawingStylesImpl = @import("../impls/CanvasPathDrawingStyles.zig");

pub const CanvasPathDrawingStyles = struct {
    pub const Meta = struct {
        pub const name = "CanvasPathDrawingStyles";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            lineWidth: f64 = undefined,
            lineCap: CanvasLineCap = undefined,
            lineJoin: CanvasLineJoin = undefined,
            miterLimit: f64 = undefined,
            lineDashOffset: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CanvasPathDrawingStyles, .{
        .deinit_fn = &deinit_wrapper,

        .get_lineCap = &get_lineCap,
        .get_lineDashOffset = &get_lineDashOffset,
        .get_lineJoin = &get_lineJoin,
        .get_lineWidth = &get_lineWidth,
        .get_miterLimit = &get_miterLimit,

        .set_lineCap = &set_lineCap,
        .set_lineDashOffset = &set_lineDashOffset,
        .set_lineJoin = &set_lineJoin,
        .set_lineWidth = &set_lineWidth,
        .set_miterLimit = &set_miterLimit,

        .call_getLineDash = &call_getLineDash,
        .call_setLineDash = &call_setLineDash,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CanvasPathDrawingStylesImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CanvasPathDrawingStylesImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_lineWidth(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return CanvasPathDrawingStylesImpl.get_lineWidth(state);
    }

    pub fn set_lineWidth(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        CanvasPathDrawingStylesImpl.set_lineWidth(state, value);
    }

    pub fn get_lineCap(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasPathDrawingStylesImpl.get_lineCap(state);
    }

    pub fn set_lineCap(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasPathDrawingStylesImpl.set_lineCap(state, value);
    }

    pub fn get_lineJoin(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasPathDrawingStylesImpl.get_lineJoin(state);
    }

    pub fn set_lineJoin(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasPathDrawingStylesImpl.set_lineJoin(state, value);
    }

    pub fn get_miterLimit(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return CanvasPathDrawingStylesImpl.get_miterLimit(state);
    }

    pub fn set_miterLimit(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        CanvasPathDrawingStylesImpl.set_miterLimit(state, value);
    }

    pub fn get_lineDashOffset(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return CanvasPathDrawingStylesImpl.get_lineDashOffset(state);
    }

    pub fn set_lineDashOffset(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        CanvasPathDrawingStylesImpl.set_lineDashOffset(state, value);
    }

    pub fn call_getLineDash(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasPathDrawingStylesImpl.call_getLineDash(state);
    }

    pub fn call_setLineDash(instance: *runtime.Instance, segments: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CanvasPathDrawingStylesImpl.call_setLineDash(state, segments);
    }

};
