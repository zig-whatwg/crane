//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasDrawPathImpl = @import("impls").CanvasDrawPath;
const CanvasFillRule = @import("enums").CanvasFillRule;
const Path2D = @import("interfaces").Path2D;

pub const CanvasDrawPath = struct {
    pub const Meta = struct {
        pub const name = "CanvasDrawPath";
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

    pub const vtable = runtime.buildVTable(CanvasDrawPath, .{
        .deinit_fn = &deinit_wrapper,

        .call_beginPath = &call_beginPath,
        .call_clip = &call_clip,
        .call_fill = &call_fill,
        .call_isPointInPath = &call_isPointInPath,
        .call_isPointInStroke = &call_isPointInStroke,
        .call_stroke = &call_stroke,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return CanvasDrawPathImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasDrawPathImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_clip(instance: *runtime.Instance, fillRule: CanvasFillRule) anyerror!void {
        
        return try CanvasDrawPathImpl.call_clip(instance, fillRule);
    }

    pub fn call_isPointInPath(instance: *runtime.Instance, x: f64, y: f64, fillRule: CanvasFillRule) anyerror!bool {
        
        return try CanvasDrawPathImpl.call_isPointInPath(instance, x, y, fillRule);
    }

    pub fn call_isPointInStroke(instance: *runtime.Instance, x: f64, y: f64) anyerror!bool {
        
        return try CanvasDrawPathImpl.call_isPointInStroke(instance, x, y);
    }

    pub fn call_beginPath(instance: *runtime.Instance) anyerror!void {
        return try CanvasDrawPathImpl.call_beginPath(instance);
    }

    pub fn call_fill(instance: *runtime.Instance, fillRule: CanvasFillRule) anyerror!void {
        
        return try CanvasDrawPathImpl.call_fill(instance, fillRule);
    }

    pub fn call_stroke(instance: *runtime.Instance) anyerror!void {
        return try CanvasDrawPathImpl.call_stroke(instance);
    }

};
