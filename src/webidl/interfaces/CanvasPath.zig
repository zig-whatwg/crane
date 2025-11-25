//! Generated from: html.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasPathImpl = @import("impls").CanvasPath;
const sequence = @import("interfaces").sequence;
const DOMPointInit = @import("dictionaries").DOMPointInit;

pub const CanvasPath = struct {
    pub const Meta = struct {
        pub const name = "CanvasPath";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "closePath", "call_closePath", 0 },
            .{ "moveTo", "call_moveTo", 2 },
            .{ "lineTo", "call_lineTo", 2 },
            .{ "quadraticCurveTo", "call_quadraticCurveTo", 4 },
            .{ "bezierCurveTo", "call_bezierCurveTo", 6 },
            .{ "arcTo", "call_arcTo", 5 },
            .{ "rect", "call_rect", 4 },
            .{ "roundRect", "call_roundRect", 4 },
            .{ "arc", "call_arc", 5 },
            .{ "ellipse", "call_ellipse", 7 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "closePath",
            "moveTo",
            "lineTo",
            "quadraticCurveTo",
            "bezierCurveTo",
            "arcTo",
            "rect",
            "roundRect",
            "arc",
            "ellipse",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*CanvasPathImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasPathImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasPathImpl.deinit(instance);
    }

    pub fn call_lineTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try CanvasPathImpl.call_lineTo(instance, x, y);
    }

    pub fn call_arcTo(instance: *runtime.Instance, x1: f64, y1: f64, x2: f64, y2: f64, radius: f64) anyerror!void {
        
        return try CanvasPathImpl.call_arcTo(instance, x1, y1, x2, y2, radius);
    }

    pub fn call_arc(instance: *runtime.Instance, x: f64, y: f64, radius: f64, startAngle: f64, endAngle: f64, counterclockwise: bool) anyerror!void {
        
        return try CanvasPathImpl.call_arc(instance, x, y, radius, startAngle, endAngle, counterclockwise);
    }

    pub fn call_moveTo(instance: *runtime.Instance, x: f64, y: f64) anyerror!void {
        
        return try CanvasPathImpl.call_moveTo(instance, x, y);
    }

    pub fn call_quadraticCurveTo(instance: *runtime.Instance, cpx: f64, cpy: f64, x: f64, y: f64) anyerror!void {
        
        return try CanvasPathImpl.call_quadraticCurveTo(instance, cpx, cpy, x, y);
    }

    pub fn call_bezierCurveTo(instance: *runtime.Instance, cp1x: f64, cp1y: f64, cp2x: f64, cp2y: f64, x: f64, y: f64) anyerror!void {
        
        return try CanvasPathImpl.call_bezierCurveTo(instance, cp1x, cp1y, cp2x, cp2y, x, y);
    }

    pub fn call_ellipse(instance: *runtime.Instance, x: f64, y: f64, radiusX: f64, radiusY: f64, rotation: f64, startAngle: f64, endAngle: f64, counterclockwise: bool) anyerror!void {
        
        return try CanvasPathImpl.call_ellipse(instance, x, y, radiusX, radiusY, rotation, startAngle, endAngle, counterclockwise);
    }

    pub fn call_closePath(instance: *runtime.Instance) anyerror!void {
        return try CanvasPathImpl.call_closePath(instance);
    }

    pub fn call_roundRect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64, radii: *const anyopaque) anyerror!void {
        
        return try CanvasPathImpl.call_roundRect(instance, x, y, w, h, radii);
    }

    pub fn call_rect(instance: *runtime.Instance, x: f64, y: f64, w: f64, h: f64) anyerror!void {
        
        return try CanvasPathImpl.call_rect(instance, x, y, w, h);
    }

};
