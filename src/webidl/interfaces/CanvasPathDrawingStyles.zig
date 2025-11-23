//! Generated from: html.idl
//! Generated at: 2025-11-23T01:22:15Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasPathDrawingStylesImpl = @import("impls").CanvasPathDrawingStyles;
const CanvasLineJoin = @import("enums").CanvasLineJoin;
const CanvasLineCap = @import("enums").CanvasLineCap;

pub const CanvasPathDrawingStyles = struct {
    pub const Meta = struct {
        pub const name = "CanvasPathDrawingStyles";
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "lineWidth", "get_lineWidth", "set_lineWidth" },
            .{ "lineCap", "get_lineCap", "set_lineCap" },
            .{ "lineJoin", "get_lineJoin", "set_lineJoin" },
            .{ "miterLimit", "get_miterLimit", "set_miterLimit" },
            .{ "lineDashOffset", "get_lineDashOffset", "set_lineDashOffset" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "setLineDash", "call_setLineDash", 1 },
            .{ "getLineDash", "call_getLineDash", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setLineDash",
            "getLineDash",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "lineWidth", "get_lineWidth", "set_lineWidth" },
            .{ "lineCap", "get_lineCap", "set_lineCap" },
            .{ "lineJoin", "get_lineJoin", "set_lineJoin" },
            .{ "miterLimit", "get_miterLimit", "set_miterLimit" },
            .{ "lineDashOffset", "get_lineDashOffset", "set_lineDashOffset" },
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
            lineWidth: f64 = undefined,
            lineCap: CanvasLineCap = undefined,
            lineJoin: CanvasLineJoin = undefined,
            miterLimit: f64 = undefined,
            lineDashOffset: f64 = undefined,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasPathDrawingStylesImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasPathDrawingStylesImpl.deinit(instance);
    }

    pub fn get_lineWidth(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasPathDrawingStylesImpl.get_lineWidth(instance);
    }

    pub fn set_lineWidth(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasPathDrawingStylesImpl.set_lineWidth(instance, value);
    }

    pub fn get_lineCap(instance: *runtime.Instance) anyerror!CanvasLineCap {
        return try CanvasPathDrawingStylesImpl.get_lineCap(instance);
    }

    pub fn set_lineCap(instance: *runtime.Instance, value: CanvasLineCap) anyerror!void {
        try CanvasPathDrawingStylesImpl.set_lineCap(instance, value);
    }

    pub fn get_lineJoin(instance: *runtime.Instance) anyerror!CanvasLineJoin {
        return try CanvasPathDrawingStylesImpl.get_lineJoin(instance);
    }

    pub fn set_lineJoin(instance: *runtime.Instance, value: CanvasLineJoin) anyerror!void {
        try CanvasPathDrawingStylesImpl.set_lineJoin(instance, value);
    }

    pub fn get_miterLimit(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasPathDrawingStylesImpl.get_miterLimit(instance);
    }

    pub fn set_miterLimit(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasPathDrawingStylesImpl.set_miterLimit(instance, value);
    }

    pub fn get_lineDashOffset(instance: *runtime.Instance) anyerror!f64 {
        return try CanvasPathDrawingStylesImpl.get_lineDashOffset(instance);
    }

    pub fn set_lineDashOffset(instance: *runtime.Instance, value: f64) anyerror!void {
        try CanvasPathDrawingStylesImpl.set_lineDashOffset(instance, value);
    }

    pub fn call_getLineDash(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CanvasPathDrawingStylesImpl.call_getLineDash(instance);
    }

    pub fn call_setLineDash(instance: *runtime.Instance, segments: *const anyopaque) anyerror!void {
        
        return try CanvasPathDrawingStylesImpl.call_setLineDash(instance, segments);
    }

};
