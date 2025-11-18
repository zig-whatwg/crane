//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const Path2DImpl = @import("impls").Path2D;
const CanvasPath = @import("interfaces").CanvasPath;
const (Path2D or DOMString) = @import("interfaces").(Path2D or DOMString);
const DOMMatrix2DInit = @import("dictionaries").DOMMatrix2DInit;
const (unrestricted double or DOMPointInit or sequence) = @import("interfaces").(unrestricted double or DOMPointInit or sequence);

pub const Path2D = struct {
    pub const Meta = struct {
        pub const name = "Path2D";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            CanvasPath,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Path2D, .{
        .deinit_fn = &deinit_wrapper,

        .call_addPath = &call_addPath,
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
        
        // Initialize the instance (Impl receives full instance)
        Path2DImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        Path2DImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, path: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try Path2DImpl.constructor(instance, path);
        
        return instance;
    }

    pub fn call_lineTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try Path2DImpl.call_lineTo(instance, x, y);
    }

    pub fn call_arcTo(instance: *runtime.Instance, x1: f64, y1: f64, x2: f64, y2: f64, radius: f64) anyerror!void {
        
        return try Path2DImpl.call_arcTo(instance, x1, y1, x2, y2, radius);
    }

    pub fn call_arc(instance: *runtime.Instance, x: f64, y: f64, radius: f64, startAngle: f64, endAngle: f64, counterclockwise: bool) anyerror!void {
        
        return try Path2DImpl.call_arc(instance, x, y, radius, startAngle, endAngle, counterclockwise);
    }

    pub fn call_moveTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try Path2DImpl.call_moveTo(instance, x, y);
    }

    pub fn call_quadraticCurveTo(instance: *runtime.Instance, cpx: f64, cpy: f64, x: f64, y: f64) anyerror!void {
        
        return try Path2DImpl.call_quadraticCurveTo(instance, cpx, cpy, x, y);
    }

    pub fn call_bezierCurveTo(instance: *runtime.Instance, cp1x: f64, cp1y: f64, cp2x: f64, cp2y: f64, x: f64, y: f64) anyerror!void {
        
        return try Path2DImpl.call_bezierCurveTo(instance, cp1x, cp1y, cp2x, cp2y, x, y);
    }

    pub fn call_ellipse(instance: *runtime.Instance, x: f64, y: f64, radiusX: f64, radiusY: f64, rotation: f64, startAngle: f64, endAngle: f64, counterclockwise: bool) anyerror!void {
        
        return try Path2DImpl.call_ellipse(instance, x, y, radiusX, radiusY, rotation, startAngle, endAngle, counterclockwise);
    }

    pub fn call_addPath(instance: *runtime.Instance, path: Path2D, transform: DOMMatrix2DInit) anyerror!void {
        
        return try Path2DImpl.call_addPath(instance, path, transform);
    }

    pub fn call_closePath(instance: *runtime.Instance) anyerror!void {
        return try Path2DImpl.call_closePath(instance);
    }

    pub fn call_roundRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64, radii: anyopaque) anyerror!void {
        
        return try Path2DImpl.call_roundRect(instance, x, y, w, h, radii);
    }

    pub fn call_rect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        
        return try Path2DImpl.call_rect(instance, x, y, w, h);
    }

};
